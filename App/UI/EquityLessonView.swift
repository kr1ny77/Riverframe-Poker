import SwiftUI
import PokerCore

private actor EquityLessonCalculator {
    func calculate(_ question:KnownHandEquityQuestion) throws -> KnownHandEquityResult {
        try question.calculate()
    }
}

struct EquityLessonView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss
    @State private var index=0
    @State private var result: KnownHandEquityResult?
    @State private var answer=""
    @FocusState private var answerFocused:Bool
    @State private var review: PracticeAttempt?
    @State private var saved=false
    @State private var error: String?
    @State private var finished=false
    @State private var completed: [PracticeAttempt]=[]
    private let calculator=EquityLessonCalculator()
    private let questions: [KnownHandEquityQuestion]
    private let selectionError: String?
    init(exerciseKey: String? = nil) {
        if let exerciseKey {
            let selected = KnownHandEquityQuestion.examples.first { $0.id == exerciseKey }
            questions = selected.map { [$0] } ?? []
            selectionError = selected == nil ? "Задание \(exerciseKey) отсутствует в каталоге equity." : nil
        } else {
            questions = KnownHandEquityQuestion.examples
            selectionError = nil
        }
    }
    private var question: KnownHandEquityQuestion { questions[index] }
    private var value: Double? { Double(answer.replacingOccurrences(of:",",with:".")) }
    private var valid: Bool { value.map { $0.isFinite && (0...100).contains($0) } ?? false }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
                    LessonHeader(title:"Equity двух рук",detail:"Средняя доля банка · точный перебор")
                        .id("equity.top")
                    if let selectionError { ErrorNotice(text: selectionError) }
                    else if finished {
                        Text("Набор завершён").font(.title2.bold())
                        MetricStrip(items:[("Верно","\(completed.filter(\.isCorrect).count) из \(completed.count)"),("Допуск","±0,5 п.п.")])
                        CourseFinishView(lesson:.knownEquity)
                        Button("К темам") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        MetricStrip(items:[("Задача","\(index+1) из \(questions.count)"),("Улица",question.board.count == 3 ? "Флоп" : "Тёрн"),("Формат","NLHE")])
                        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
                            Text("Оцените equity к риверу").font(.headline)
                            Text("Победа даёт весь банк, ничья — половину. Введите значение от 0 до 100 %.")
                                .foregroundStyle(AppTheme.muted)
                            if typeSize.isAccessibilitySize {
                                CardStrip(cards:question.hero,label:"Ваши карты")
                                CardStrip(cards:question.opponent,label:"Карты соперника")
                            } else {
                                HStack(alignment:.top,spacing:16) {
                                    CardStrip(cards:question.hero,label:"Ваши карты")
                                    CardStrip(cards:question.opponent,label:"Карты соперника")
                                }
                            }
                            CardStrip(cards:question.board,label:"Общие карты")
                        }
                        .padding(AppTheme.Measure.d16)
                        .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppTheme.radius))
                        Text("Один общий банк, ставки завершены. Позиции и стеки в этот расчёт не входят.")
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                        if let result {
                            if let review { feedback(review,result:result) }
                            else {
                                TextField("Equity, %",text:$answer,prompt:Text("Equity, %").foregroundStyle(AppTheme.muted)).equityKeyboard().focused($answerFocused).lessonInput()
                                    .accessibilityIdentifier("equity.answer")
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
                .onChange(of:index) { _,_ in proxy.scrollTo("equity.top",anchor:.top) }
                .onChange(of:finished) { _,_ in proxy.scrollTo("equity.top",anchor:.top) }
        }.lessonCanvas()
            .lessonKeyboardToolbar { answerFocused=false }
            .navigationTitle("Equity")
            .task(id:index) {
                guard selectionError == nil else { return }
                await calculate()
            }
    }
    private func feedback(_ review:PracticeAttempt,result:KnownHandEquityResult) -> some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Text(review.isCorrect ? "Верно по условию" : "Разберём расчёт").font(.headline)
            MetricStrip(items:[("Ваш ответ",String(format:"%.2f %%",review.answer)),("Equity",String(format:"%.2f %%",result.equityPercent)),("Исходов","\(result.total)")])
            EquityMeter(percent:result.equityPercent,caption:"Ваша средняя доля банка")
            OutcomeDistribution(wins:result.wins,ties:result.ties,losses:result.losses)
            Text(question.board.count == 3
                 ? "Точный перебор: 45 × 44 / 2 = 990 пар тёрн–ривер."
                 : "Точный перебор: 44 возможных ривера.")
            DisclosureGroup("Подробнее о расчёте") {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    ForEach(result.explanation,id:\.self) { Text($0) }
                }.font(.footnote).foregroundStyle(AppTheme.muted)
            }
            if saved {
                Text("Результат сохранён на устройстве.").foregroundStyle(AppTheme.success)
                Button(questions.count == 1 ? "Завершить урок" : index == 0 ? "К задаче на тёрне" : "Завершить урок") {
                    completed.append(review)
                    if index + 1 < questions.count { self.review=nil; self.result=nil; saved=false; answer=""; error=nil; index+=1 }
                    else { finished=true }
                }.buttonStyle(PrimaryButtonStyle())
            } else {
                if let error { ErrorNotice(text:error) }
                Button("Повторить сохранение") { save() }.buttonStyle(SecondaryButtonStyle())
            }
        }.accessibilityIdentifier("equity.feedback")
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
    private func submit(_ result:KnownHandEquityResult) {
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
    @ViewBuilder func equityKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
