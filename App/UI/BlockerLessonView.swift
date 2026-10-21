import SwiftUI
import PokerCore

struct BlockerLessonView: View {
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss
    @State private var index=0
    @State private var review: BlockerAttempt?
    @State private var saved=false
    @State private var saveError: String?
    @State private var completed: [BlockerAttempt]=[]
    @State private var finished=false
    @ScaledMetric(relativeTo:.body) private var cardWidth=AppTheme.Metrics.boardCard.width
    private let questions: [BlockerQuestion]
    private let selectionError: String?
    init(exerciseKey: String? = nil) {
        if let exerciseKey {
            let selected = BlockerQuestion.examples.first { $0.id == exerciseKey }
            questions = selected.map { [$0] } ?? []
            selectionError = selected == nil ? "Задание \(exerciseKey) отсутствует в каталоге блокеров." : nil
        } else {
            questions = BlockerQuestion.examples
            selectionError = nil
        }
    }
    private var question: BlockerQuestion { questions[index] }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
                    LessonHeader(title:"Блокеры",detail:"Как известные карты меняют число комбинаций").id("blockers.top")
                    if let selectionError { ErrorNotice(text: selectionError) }
                    else if finished {
                        Text("Набор завершён").font(.title3.weight(.semibold))
                        MetricStrip(items:[("Верно", "\(completed.filter(\.isCorrect).count)/\(completed.count)"), ("Задач", "\(completed.count)")])
                        Text("Проверены подсчёт, удаление и нормировка весов. Прогресс отражает ответы на фиксированные учебные задачи.")
                        CourseFinishView(lesson:.blockers)
                        Button("К темам") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else { exercise }
                }.padding()
            }.lessonCanvas()
                .onChange(of:index) { _,_ in proxy.scrollTo("blockers.top",anchor:.top) }
                .onChange(of:finished) { _,_ in proxy.scrollTo("blockers.top",anchor:.top) }
        }.navigationTitle("Комбинации диапазона")
    }
    private var exercise: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Label("Задание \(index+1) из \(questions.count)",systemImage:"rectangle.3.group.fill").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
            Text("Известные карты удаляют комбинации из заданного диапазона.").font(.title3.weight(.semibold))
            DisclosureGroup("Правило подсчёта") {
                FormulaSteps(lines:["Пара: C(4,2) = 6; одномастная рука (s): 4; разномастная (o): 4 × 3 = 12.", "Каждая известная карта исключает комбинации соперника, которые содержат эту карту."])
            }
            Text(question.isRangeModel ? BlockerQuestion.rangeConditions : "NLHE · флоп. Считаем карманные карты одного соперника. Стеки, ставки и действия в этот подсчёт не входят.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            CardStrip(cards:question.hero,label:"Карты Hero")
            CardStrip(cards:question.board,label:"Доска · \(question.board.count == 3 ? "флоп" : "ривер")")
            Text("Заданный набор рук").font(.headline)
            ForEach(question.range) { entry in
                HStack {
                    Text(entry.hand.title).font(.headline)
                    Spacer()
                    Text("\(entry.hand.combinations.count) · \(entry.role.title) · вес \(entry.weight)").font(.footnote).foregroundStyle(AppTheme.muted)
                }
            }
            if question.isRangeModel {
                Text("Веса — относительная масса каждой разрешённой комбинации после ставки BB. При удалении карт веса остальных комбинаций сохраняются; затем нормируем их сумму. Эта учебная модель задаёт весь рассматриваемый диапазон.").font(.footnote)
            }
            Text(question.prompt).font(.title3.weight(.semibold))
            if let review { feedback(review) }
            else {
                ForEach(question.choices.indices,id:\.self) { choice in
                    Button(question.choiceTitle(choice)) { choose(choice) }.buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("blockers.answer.\(choice)")
                }
            }
            Text(BlockerQuestion.scope).font(.footnote).foregroundStyle(AppTheme.muted)
            DisclosureGroup("Источники и модель") {
                Text("Собственные задачи blockers-v1 · 17.10.2026. Точный перебор сочетаний карт; веса и категории созданы для этих примеров. Стратегия реального соперника потребует отдельного обоснования.").font(.footnote)
                Link("GTO Wizard · Poker Combinatorics",destination:URL(string:"https://blog.gtowizard.com/a-beginners-guide-to-poker-combinatorics/")!)
                Link("GTO Wizard · Understanding Blockers",destination:URL(string:"https://blog.gtowizard.com/understanding-blockers-in-poker/")!)
            }
        }
    }
    private func feedback(_ review:BlockerAttempt) -> some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Label(review.isCorrect ? "Верно по модели" : "Разберём комбинации",systemImage:review.isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.title3.weight(.semibold)).foregroundStyle(review.isCorrect ? AppTheme.success : AppTheme.warning)
            Text("Ваш ответ: \(question.choiceTitle(review.answerIndex))")
            ForEach(question.rows) { row in
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    Text(row.entry.hand.title).font(.headline)
                    RemovalPipeline(baseline:row.baseline.count,afterHero:row.afterHero.count,remaining:row.remaining.count)
                        .accessibilityIdentifier("blockers.counts.\(row.id)")
                    Text("Полный каталог → после Hero → после доски. Исключено: \(row.exclusions.count).")
                    Text("Остались: \(row.remaining.isEmpty ? "0 комбинаций" : row.remaining.map(\.title).joined(separator:"; ")).")
                    DisclosureGroup("Исключения \(row.id) (\(row.exclusions.count))") {
                        Text("Сначала удаляем комбинации с картами Hero, затем из оставшихся — с доской. Комбинация, затронутая обоими этапами, учитывается один раз на этапе Hero.").font(.footnote)
                        ForEach(row.exclusions) { exclusion in Text(exclusion.explanation).font(.footnote) }
                    }.accessibilityIdentifier("blockers.exclusions.\(row.id)")
                }
            }
            Text("Всего осталось: \(question.remainingCount) комбинаций.").accessibilityIdentifier("blockers.total")
            RemovalPipeline(baseline:question.rows.reduce(0) { $0+$1.baseline.count },afterHero:question.rows.reduce(0) { $0+$1.afterHero.count },remaining:question.remainingCount)
            Text(question.lessonNote)
            if question.isRangeModel { frequency }
            if saved {
                Text("Результат сохранён на устройстве.").foregroundStyle(AppTheme.success)
                Button(index+1 == questions.count ? "Завершить урок" : "Следующее задание") {
                    completed.append(review)
                    if index+1 == questions.count { finished=true }
                    else { self.review=nil;saved=false;saveError=nil;index+=1 }
                }.buttonStyle(PrimaryButtonStyle())
            } else {
                if let saveError { ErrorNotice(text:saveError) }
                Button("Повторить сохранение") { save() }.buttonStyle(SecondaryButtonStyle())
            }
        }
    }
    private var frequency: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
            ForEach(question.rows) { row in
                Text("\(row.entry.role.title): \(row.remaining.count) × вес \(row.entry.weight) = \(row.remaining.count*row.entry.weight) единиц массы.")
            }
            if let percent=question.bluffPercent {
                Text("Доля блефов по модели: \(question.bluffMass) / (\(question.valueMass) + \(question.bluffMass)) × 100 = \(String(format:"%.2f",percent)) %.")
                    .accessibilityIdentifier("blockers.frequency")
                Text("Доля value по модели: \(question.valueMass) / (\(question.valueMass) + \(question.bluffMass)) × 100 = \(String(format:"%.2f",100-percent)) %.")
                    .accessibilityIdentifier("blockers.value-frequency")
                let boardBluffs=question.rows.filter { $0.entry.role == .bluff }.reduce(0) { $0+$1.boardOnly.count*$1.entry.weight }
                let boardValue=question.rows.filter { $0.entry.role == .value }.reduce(0) { $0+$1.boardOnly.count*$1.entry.weight }
                Text("Для сравнения: каталог при учёте только доски даёт \(boardBluffs) / \(boardBluffs+boardValue) = \(String(format:"%.2f",100*Double(boardBluffs)/Double(boardBluffs+boardValue))) % блефов. Учёт Hero меняет состав каталога и нормировку весов.")
                Text("Оставшиеся value-руки также возможны. Блокер уточняет условную долю внутри модели; фактическая рука и намерение соперника остаются неизвестны.")
            } else { Text("Модель не содержит допустимых комбинаций; доля блефов не определена.") }
        }
    }
    private func choose(_ choice:Int) {
        guard review == nil else { return }
        do { review=try BlockerAttempt(questionID:question.id,answerIndex:choice);save() }
        catch { saveError="Ответ обработать не удалось: \(error.localizedDescription)" }
    }
    private func save() {
        guard let review,!saved else { return }
        do { try store.record(review);saved=true;saveError=nil }
        catch { saveError="Ответ проверен. Сохранить пока не удалось: \(error.localizedDescription)" }
    }
}
