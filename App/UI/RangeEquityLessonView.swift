import SwiftUI
import PokerCore

private actor RangeEquityLessonCalculator {
    func calculate(_ question:RangeEquityQuestion) throws -> RangeEquityResult {
        try question.calculate()
    }
}

struct RangeEquityLessonView: View {
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss
    @State private var index=0
    @State private var result: RangeEquityResult?
    @State private var answer=""
    @FocusState private var answerFocused:Bool
    @State private var review: PracticeAttempt?
    @State private var saved=false
    @State private var error: String?
    @State private var finished=false
    @State private var completed: [PracticeAttempt]=[]
    private let calculator=RangeEquityLessonCalculator()
    private let questions: [RangeEquityQuestion]
    private let selectionError: String?
    init(exerciseKey: String? = nil) {
        if let exerciseKey {
            let selected = RangeEquityQuestion.examples.first { $0.id == exerciseKey }
            questions = selected.map { [$0] } ?? []
            selectionError = selected == nil ? "Задание \(exerciseKey) отсутствует в каталоге equity диапазона." : nil
        } else {
            questions = RangeEquityQuestion.examples
            selectionError = nil
        }
    }
    private var question: RangeEquityQuestion { questions[index] }
    private var value: Double? { Double(answer.replacingOccurrences(of:",",with:".")) }
    private var valid: Bool { value.map { $0.isFinite && (0...100).contains($0) } ?? false }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
                    LessonHeader(title:"Equity против диапазона",detail:"Точное среднее по заданным весам")
                        .id("range-equity.top")
                    if let selectionError { ErrorNotice(text: selectionError) }
                    else if finished {
                        Text("Набор завершён").font(.title2.bold())
                        MetricStrip(items:[("Верно","\(completed.filter(\.isCorrect).count) из \(completed.count)"),("Допуск","±0,5 п.п.")])
                        CourseFinishView(lesson:.rangeEquity)
                        Button("К темам") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        MetricStrip(items:[("Задача","\(index+1) из \(questions.count)"),("Улица",question.board.count == 3 ? "Флоп" : "Тёрн"),("Формат","NLHE")])
                        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
                            Text("Оцените equity к риверу").font(.headline)
                            Text("Победа даёт весь банк, ничья — половину. Диапазон ниже задан только для этой задачи.")
                                .foregroundStyle(AppTheme.muted)
                            CardStrip(cards:question.hero,label:"Ваши карты")
                            CardStrip(cards:question.board,label:"Общие карты")
                        }
                        .padding(AppTheme.Measure.d16)
                        .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppTheme.radius))
                        rangeContext
                        if let result {
                            if let review { feedback(review,result:result) }
                            else {
                                TextField("Equity, %",text:$answer,prompt:Text("Equity, %").foregroundStyle(AppTheme.muted)).rangeEquityKeyboard().focused($answerFocused).lessonInput()
                                    .accessibilityIdentifier("range-equity.answer")
                                if !answer.isEmpty && !valid { Text("Введите число от 0 до 100.").font(.footnote).foregroundStyle(AppTheme.danger) }
                                Button("Проверить") { submit(result) }.buttonStyle(PrimaryButtonStyle()).disabled(!valid)
                            }
                        } else if let error {
                            ErrorNotice(text:error)
                            Button("Повторить расчёт") { self.error=nil; Task { await calculate() } }.buttonStyle(SecondaryButtonStyle())
                        } else {
                            SwiftUI.ProgressView("Перебираем оставшиеся карты…")
                        }
                    }
                }.padding()
            }
                .onChange(of:index) { _,_ in proxy.scrollTo("range-equity.top",anchor:.top) }
                .onChange(of:finished) { _,_ in proxy.scrollTo("range-equity.top",anchor:.top) }
        }.lessonCanvas()
            .lessonKeyboardToolbar { answerFocused=false }
            .navigationTitle("Equity диапазона")
            .task(id:index) {
                guard selectionError == nil else { return }
                await calculate()
            }
    }
    private var rangeContext: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Text("Диапазон соперника").font(.headline)
            ForEach(question.range,id:\.id) { hand in
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    CardStrip(cards:hand.cards)
                    VStack(alignment:.leading,spacing:AppTheme.Measure.d3) {
                        Text("Вес \(hand.weight) из \(question.totalWeight)").font(.subheadline.weight(.medium))
                        SwiftUI.ProgressView(value:Double(hand.weight),total:Double(question.totalWeight))
                            .tint(AppTheme.accent)
                        Text("\(String(format:"%.1f",100*Double(hand.weight)/Double(question.totalWeight))) % в модели")
                            .font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
                .accessibilityElement(children:.combine)
                .accessibilityLabel("Рука диапазона: \(hand.cards.map(\.label).joined(separator:", ")). Вес \(hand.weight) из \(question.totalWeight)")
            }
            Text("Веса описывают предположение о частоте рук в этом диапазоне. Они меняют итоговую equity.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
        }
        .padding(AppTheme.Measure.d16)
        .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppTheme.radius))
    }
    private func feedback(_ review:PracticeAttempt,result:RangeEquityResult) -> some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Text(review.isCorrect ? "Верно по условию" : "Разберём расчёт").font(.headline)
            MetricStrip(items:[("Ваш ответ",String(format:"%.2f %%",review.answer)),("Equity",String(format:"%.2f %%",result.equityPercent)),("Весов","\(result.totalWeight)")])
            EquityMeter(percent:result.equityPercent,caption:"Ваша средняя доля банка по заданному диапазону")
            ForEach(result.rows) { row in
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    CardStrip(cards:row.hand.cards)
                    Text("Вес в модели: \(String(format:"%.1f",100*Double(row.hand.weight)/Double(result.totalWeight))) %")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                    MetricStrip(items:[("Вес","\(row.hand.weight) / \(result.totalWeight)"),("Equity",String(format:"%.2f %%",row.outcomes.equityPercent)),("Исходов","\(row.outcomes.total)")])
                    OutcomeDistribution(wins:row.outcomes.wins,ties:row.outcomes.ties,losses:row.outcomes.losses)
                }
                .padding(AppTheme.Measure.d12)
                .background(AppTheme.surfaceAlt,in:RoundedRectangle(cornerRadius:AppTheme.Measure.d12))
            }
            DisclosureGroup("Подробнее о расчёте") {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    ForEach(result.explanation,id:\.self) { Text($0) }
                }.font(.footnote).foregroundStyle(AppTheme.muted)
            }
            if saved {
                Text("Результат сохранён на устройстве.").foregroundStyle(AppTheme.success)
                Button(index+1 < questions.count ? "Следующая задача" : "Завершить урок") {
                    completed.append(review)
                    if index+1 < questions.count { self.review=nil; self.result=nil; saved=false; answer=""; error=nil; index+=1 }
                    else { finished=true }
                }.buttonStyle(PrimaryButtonStyle())
            } else {
                if let error { ErrorNotice(text:error) }
                Button("Повторить сохранение") { save() }.buttonStyle(SecondaryButtonStyle())
            }
        }.accessibilityIdentifier("range-equity.feedback")
    }
    private func calculate() async {
        let current=question
        do {
            let computed=try await calculator.calculate(current)
            guard !Task.isCancelled,question.id == current.id else { return }
            result=computed; error=nil
        } catch is CancellationError { }
        catch { self.error="Расчёт выполнить не удалось: \(error.localizedDescription)" }
    }
    private func submit(_ result:RangeEquityResult) {
        guard review == nil,valid,let value else { return }
        answerFocused=false
        review=PracticeAttempt(question:question,result:result,answer:value)
        save()
    }
    private func save() {
        guard let review,!saved else { return }
        do { try store.record(review);saved=true;error=nil }
        catch { self.error="Ответ проверен. Сохранить пока не удалось: \(error.localizedDescription)" }
    }
}

private extension View {
    @ViewBuilder func rangeEquityKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
