import SwiftUI
import PokerCore

private struct SixMaxSeatMap: View {
    let button: Int
    let heroSeat: Int
    @ScaledMetric(relativeTo:.body) private var columnWidth:CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Места по часовой стрелке").font(.headline)
            Text("Hero — вы. D — кнопка дилера.").font(.footnote).foregroundStyle(AppTheme.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: 8)], spacing: 8) {
                ForEach(0..<6, id: \.self) { seat in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Место \(seat + 1)").font(.caption).foregroundStyle(AppTheme.muted)
                        Text(seat == heroSeat ? (seat == button ? "Hero · D" : "Hero") : seat == button ? "D · кнопка" : "Соперник")
                            .font(.subheadline.weight(seat == heroSeat ? .semibold : .regular))
                            .foregroundStyle(seat == heroSeat ? AppTheme.accent : AppTheme.text)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(8)
                    .background(seat == heroSeat ? AppTheme.surfaceAlt : AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(seat == heroSeat ? AppTheme.accent : AppTheme.border, lineWidth: 1))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct PositionLessonView: View {
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss
    @State private var introductory=true
    @State private var index=0
    @State private var review: PositionAttempt?
    @State private var saved=false
    @State private var saveError: String?
    @State private var finished=false
    @State private var run:[PositionAttempt]=[]
    @ScaledMetric(relativeTo:.body) private var cardWidth=AppTheme.Metrics.boardCard.width
    private let questions: [PositionQuestion]
    private let selectionError: String?

    init(exerciseKey: String? = nil) {
        _introductory = State(initialValue: exerciseKey == nil)
        if let exerciseKey {
            let selected = PositionLesson.questions.first { $0.id == exerciseKey }
            questions = selected.map { [$0] } ?? []
            selectionError = selected == nil ? "Задание \(exerciseKey) отсутствует в каталоге позиций." : nil
        } else {
            questions = PositionLesson.questions
            selectionError = nil
        }
    }
    private var question: PositionQuestion { questions[index] }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
                    LessonHeader(title:"Позиции",detail:"6-max: место за столом и порядок решений").id("positions.top")
                    if let selectionError { ErrorNotice(text: selectionError) }
                    else if introductory { introduction }
                    else if finished {
                        Text("Набор завершён").font(.title3.weight(.semibold))
                        MetricStrip(items:[("Верно", "\(run.filter(\.isCorrect).count)/\(run.count)"), ("Задач", "\(run.count)")])
                        Text("Проверены понятия и порядок действий.")
                        Text("Результат относится к заданиям модуля. Для выбора диапазона нужны источник, стек, анте, рейк и конкретная линия.")
                        CourseFinishView(lesson:.positions)
                        Button("К темам") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else { exercise }
                    DisclosureGroup("Источники и границы материала") {
                        VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                            Text("Материал v1 · проверка 17.10.2026. У публичных страниц отдельная версия не обозначена.")
                            ForEach(PositionLesson.sources,id:\.url) { source in
                                if let url=URL(string:source.url) { Link(source.title,destination:url) }
                            }
                            Text(PositionLesson.scope)
                        }.font(.footnote)
                    }
                }.padding()
            }.lessonCanvas()
                .onChange(of:index) { _,_ in proxy.scrollTo("positions.top",anchor:.top) }
                .onChange(of:introductory) { _,_ in proxy.scrollTo("positions.top",anchor:.top) }
                .onChange(of:finished) { _,_ in proxy.scrollTo("positions.top",anchor:.top) }
        }.navigationTitle("Позиции · 6-max")
    }
    private var introduction: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Text("Шесть мест, два порядка действий").font(.title3.weight(.semibold))
            Text(PositionLesson.conditions).font(.subheadline).foregroundStyle(AppTheme.muted)
            VStack(alignment:.leading,spacing:6) {
                ForEach(SixMaxPosition.clockwiseFromButton,id:\.self) { position in
                    Text(position.title).font(.subheadline)
                }
            }.padding(12).background(AppTheme.surface,in:RoundedRectangle(cornerRadius:12))
            FormulaSteps(lines:PositionLesson.introduction)
            Button("Начать упражнения") { introductory=false }.buttonStyle(PrimaryButtonStyle())
        }
    }
    private var exercise: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Label("Задание \(index+1) из \(questions.count)",systemImage:"location.fill").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
            Text(PositionLesson.conditions).font(.footnote).foregroundStyle(AppTheme.muted)
            if !question.recognition,let position=try? SixMaxPosition.at(seat:question.heroSeat,button:question.button) {
                Text("Hero: \(position.rawValue)").font(.title3.weight(.semibold))
            }
            Text(question.context)
            if question.recognition {
                SixMaxSeatMap(button:question.button,heroSeat:question.heroSeat)
            }
            ForEach(Array(question.hands.enumerated()),id:\.offset) { item in
                Text("Вариант \(item.offset == 0 ? "A" : "B")").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:cardWidth+AppTheme.Measure.d6))],alignment:.leading) {
                    ForEach(item.element) { card in
                        PlayingCardView(card:card,size:CGSize(width:cardWidth,height:cardWidth*AppTheme.Metrics.boardCard.height/AppTheme.Metrics.boardCard.width))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                }
            }
            Text(question.prompt).font(.title3.weight(.semibold))
            if let review { feedback(review) }
            else {
                ForEach(question.choices.indices,id:\.self) { choice in
                    Button(question.choices[choice]) { choose(choice) }.buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("positions.answer.\(choice)")
                }
            }
            Text(PositionLesson.scope).font(.footnote).foregroundStyle(AppTheme.muted)
        }
    }
    private func feedback(_ review:PositionAttempt) -> some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Label(review.isCorrect ? "Верно по условию" : "Разберём ответ",systemImage:review.isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.title3.weight(.semibold)).foregroundStyle(review.isCorrect ? AppTheme.success : AppTheme.warning)
            Text("Ваш ответ: \(question.choices[review.answerIndex])")
            Text("Ответ по условию: \(question.choices[question.correctIndex])")
            FormulaSteps(lines:[question.explanation])
            if saved {
                Text("Результат сохранён на устройстве.").foregroundStyle(AppTheme.success)
                Button(index+1 == questions.count ? "Завершить урок" : "Следующее задание") {
                    run.append(review)
                    if index+1 == questions.count { finished=true }
                    else { index+=1;self.review=nil;saved=false;saveError=nil }
                }.buttonStyle(PrimaryButtonStyle())
            } else {
                if let saveError { ErrorNotice(text:saveError) }
                Button("Повторить сохранение") { save() }.buttonStyle(SecondaryButtonStyle())
            }
        }
    }
    private func choose(_ answer:Int) {
        guard review == nil else { return }
        do { review=try PositionAttempt(question:question,answerIndex:answer);save() }
        catch { saveError="Ответ обработать не удалось: \(error.localizedDescription)" }
    }
    private func save() {
        guard let review,!saved else { return }
        do { try store.record(review);saved=true;saveError=nil }
        catch { saveError="Ответ проверен. Сохранить пока не удалось: \(error.localizedDescription)" }
    }
}
