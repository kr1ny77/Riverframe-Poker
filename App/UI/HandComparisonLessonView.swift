import SwiftUI
import PokerCore

private struct BestFiveComparison: View {
    let first: [Card]
    let firstTitle: String
    let second: [Card]
    let secondTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Лучшая пятёрка").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                CardStrip(cards: first, label: "Игрок A · \(firstTitle)")
                Divider().overlay(AppTheme.border)
                CardStrip(cards: second, label: "Игрок B · \(secondTitle)")
            }
            .padding(12)
            .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .contain)
    }
}

struct HandComparisonLessonView: View {
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [HandComparisonQuestion]
    @State private var index = 0
    @State private var selected = Set<Card>()
    @State private var review: HandComparisonAttempt?
    @State private var saved = false
    @State private var saveError: String?
    @State private var finished = false
    @State private var run: [HandComparisonAttempt] = []
    @ScaledMetric(relativeTo:.body) private var cardWidth = AppTheme.Metrics.boardCard.width
    private let exerciseKey: String?
    private let selectionError: String?

    init(exerciseKey: String? = nil) {
        var seed = UInt64.random(in:1...UInt64.max)
        #if DEBUG && targetEnvironment(simulator)
        if let value = ProcessInfo.processInfo.environment["POKER_QA_COMPARISON_SEED"], let parsed = UInt64(value) { seed = parsed }
        #endif
        self.exerciseKey = exerciseKey
        let allQuestions = HandComparisonLesson.questions(seed: exerciseKey == nil ? seed : 7)
        if let exerciseKey {
            let selected = allQuestions.first { Self.templateKey(for: $0.id) == exerciseKey }
            _questions = State(initialValue: selected.map { [$0] } ?? [])
            selectionError = selected == nil ? "Задание \(exerciseKey) отсутствует в каталоге комбинаций." : nil
        } else {
            _questions = State(initialValue:allQuestions)
            selectionError = nil
        }
    }
    private static func templateKey(for questionID: String) -> String? {
        let parts = questionID.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 5, parts[0] == "hcmp", parts[1] == "v1" else { return nil }
        return String(parts[2])
    }
    private var question: HandComparisonQuestion { questions[index] }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
                    LessonHeader(title:"Комбинации",detail:"Сравнение лучших пяти карт из семи").id("lesson-top")
                    if let selectionError { ErrorNotice(text: selectionError) }
                    else if finished { summary }
                    else {
                        Label("Задача \(index+1) из \(questions.count) · вскрытие",systemImage:"suit.spade.fill")
                            .font(.subheadline).foregroundStyle(AppTheme.muted)
                            .accessibilityIdentifier("comparison.step")
                        Text("Используйте любые пять карт из семи. Карманных карт в комбинации может быть ноль, одна или две.")
                            .font(.subheadline).foregroundStyle(AppTheme.muted)
                        context
                        if let review { feedback(review) }
                        else { answerControls }
                        Text("Ответ сохраняется в прогрессе. В этой задаче открыты обе руки на ривере; ставки и стеки не участвуют в сравнении.")
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                    }
                }.padding()
            }
            .lessonCanvas()
            .onChange(of:index) { _, _ in proxy.scrollTo("lesson-top",anchor:.top) }
            .onChange(of:finished) { _, _ in proxy.scrollTo("lesson-top",anchor:.top) }
        }
        .navigationTitle("Комбинации")
    }

    private var context: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Text(question.mode == .winner ? "Кто забирает банк?" : "Выберите лучшую пятёрку игрока A")
                .font(.title3.weight(.semibold)).accessibilityIdentifier("comparison.prompt")
            Text("Игрок A").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
            cards(question.first,selectable:question.mode == .bestFive && review == nil)
            Text("Игрок B").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
            cards(question.second,selectable:false)
            Text("Общие карты · ривер").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
            cards(question.board,selectable:question.mode == .bestFive && review == nil)
        }.padding().frame(maxWidth:.infinity,alignment:.leading)
            .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppTheme.radius))
    }
    private var lessonCardSize: CGSize {
        CGSize(width:cardWidth,height:cardWidth * AppTheme.Metrics.boardCard.height / AppTheme.Metrics.boardCard.width)
    }
    private func cards(_ values:[Card],selectable:Bool) -> some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:cardWidth + AppTheme.Measure.d6),spacing:AppTheme.Measure.d6)],alignment:.leading,spacing:AppTheme.Measure.d12) {
            ForEach(values) { card in cardView(card,selectable:selectable) }
        }
    }
    @ViewBuilder private func cardView(_ card:Card,selectable:Bool) -> some View {
        if selectable {
            Button {
                if selected.contains(card) { selected.remove(card) }
                else if selected.count < 5 { selected.insert(card) }
            } label: {
                VStack(spacing:AppTheme.Measure.d3) {
                    PlayingCardView(card:card,size:lessonCardSize).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    Image(systemName:selected.contains(card) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.contains(card) ? AppTheme.accent : AppTheme.muted)
                }
                .padding(AppTheme.Measure.d3)
                .overlay(RoundedRectangle(cornerRadius:AppTheme.Measure.d7).stroke(selected.contains(card) ? AppTheme.accent : .clear,lineWidth:AppTheme.Measure.d2))
            }.buttonStyle(.plain)
                .accessibilityLabel(card.label)
                .accessibilityValue(selected.contains(card) ? "Выбрана" : "Доступна для выбора")
                .accessibilityIdentifier("comparison.card.\(card.id)")
        } else {
            PlayingCardView(card:card,size:lessonCardSize).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
    @ViewBuilder private var answerControls: some View {
        if question.mode == .winner {
            ForEach(ShowdownWinner.allCases,id:\.rawValue) { winner in
                Button(winner.title) { choose(.winner(winner)) }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("comparison.answer.\(winner.rawValue)")
            }
        } else {
            Text("Выбрано \(selected.count) из 5 карт").font(.headline)
            Text("Отметьте пять карт среди карт игрока A и общей доски, затем проверьте ответ.").font(.subheadline)
            Button("Проверить пятёрку") { choose(.bestFive(selected.sorted { $0.id < $1.id })) }
                .buttonStyle(PrimaryButtonStyle()).disabled(selected.count != 5)
                .accessibilityIdentifier("comparison.check")
        }
    }
    private func feedback(_ attempt:HandComparisonAttempt) -> some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Label(attempt.isCorrect ? "Верно по картам" : "Разберём сравнение",systemImage:attempt.isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.title3.weight(.semibold)).foregroundStyle(attempt.isCorrect ? AppTheme.success : AppTheme.warning)
                .accessibilityIdentifier("comparison.feedback")
            Text(answerDescription(attempt.answer)).accessibilityIdentifier("comparison.chosen-answer")
            if case .bestFive(let chosen) = attempt.answer {
                Text("Выбранная пятёрка: \(HandEvaluator.best(of:chosen).title)")
                cards(chosen,selectable:false)
            }
            BestFiveComparison(first:question.firstRank.bestFive,firstTitle:question.firstRank.title,second:question.secondRank.bestFive,secondTitle:question.secondRank.title)
            FormulaSteps(lines:question.explanation(for:attempt.answer))
            if saved {
                Text("Ответ сохранён на устройстве.").font(.footnote).foregroundStyle(AppTheme.success)
                Button(index+1 == questions.count ? "Завершить урок" : "Следующая задача") { advance() }
                    .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("comparison.next")
            } else {
                if let saveError { ErrorNotice(text:saveError) }
                Button("Повторить сохранение") { saveReview() }.buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("comparison.retry")
            }
        }.padding().frame(maxWidth:.infinity,alignment:.leading)
            .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppTheme.radius))
    }
    private var summary: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
            Text("Набор завершён").font(.system(.title2,design:.serif).weight(.semibold)).accessibilityIdentifier("comparison.finished")
            Text("Комбинации и сравнение рук").font(.subheadline).foregroundStyle(AppTheme.muted)
            MetricStrip(items:[("Верно", "\(run.filter(\.isCorrect).count)/\(run.count)"), ("Задач", "\(run.count)")])
            Text("Сначала сравнивайте категорию, затем значимые ранги. Равные пять карт делят банк. Масть преимущества не даёт.")
            Text("Результат относится к этому набору вскрытий. Ставки и стратегические решения требуют отдельного разбора.")
                .foregroundStyle(AppTheme.muted)
            CourseFinishView(lesson:.combinations)
            Button("Новый набор") {
                let next = HandComparisonLesson.questions(seed: exerciseKey == nil ? UInt64.random(in:1...UInt64.max) : 7)
                questions = exerciseKey.flatMap { key in next.first { Self.templateKey(for: $0.id) == key }.map { [$0] } } ?? next
                index=0;selected=[];review=nil;saved=false;saveError=nil;finished=false;run=[]
            }.buttonStyle(PrimaryButtonStyle())
            Button("К темам") { dismiss() }.buttonStyle(SecondaryButtonStyle())
        }
    }
    private func answerDescription(_ answer:HandComparisonAnswer) -> String {
        switch answer {
        case .winner(let winner): "Ваш ответ: \(winner.title)"
        case .bestFive: "Ваш ответ: пять отмеченных карт игрока A и доски."
        }
    }
    private func choose(_ answer:HandComparisonAnswer) {
        guard review == nil else { return }
        review=HandComparisonAttempt(question:question,answer:answer)
        saveReview()
    }
    private func saveReview() {
        guard let review,!saved else { return }
        do { try store.record(review);saved=true;saveError=nil }
        catch { saveError="Ответ проверен. Сохранение пока недоступно: \(error.localizedDescription)" }
    }
    private func advance() {
        guard saved,let review else { return }
        run.append(review)
        if index+1 == questions.count { finished=true }
        else { index+=1;self.review=nil;selected=[];saved=false;saveError=nil }
    }
}
