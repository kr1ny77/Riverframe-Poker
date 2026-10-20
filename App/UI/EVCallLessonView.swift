import SwiftUI
import PokerCore

struct EVCallLessonView: View {
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss
    @State private var index=0
    @State private var review: EVCallAttempt?
    @State private var saved=false
    @State private var saveError: String?
    @State private var finished=false
    @State private var completed: [EVCallAttempt]=[]
    private var question: EVCallQuestion { EVCallQuestion.examples[index] }
    private var result: EVCallResult { question.result }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
                    LessonHeader(title:"EV колла и фолда",detail:"Сравнение решений на готовой доске")
                        .id("ev.top")
                    if finished {
                        Text("Набор завершён").font(.title2.bold())
                        MetricStrip(items:[("Верно","\(completed.filter(\.isCorrect).count) из \(completed.count)"),("Модель","Ривер · all-in")])
                        Text("При EV = 0 оба действия принимаются. Счёт оценивает сравнение вариантов в заданных условиях.")
                        CourseFinishView(lesson:.evCall)
                        Button("К темам") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else { exercise }
                }.padding()
            }
                .onChange(of:index) { _,_ in proxy.scrollTo("ev.top",anchor:.top) }
                .onChange(of:finished) { _,_ in proxy.scrollTo("ev.top",anchor:.top) }
        }.lessonCanvas()
            .navigationTitle("EV: Call / Fold")
    }
    private var exercise: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            MetricStrip(items:[("Сценарий","\(index+1) из \(EVCallQuestion.examples.count)"),("Улица","Ривер"),("Формат","NLHE cash")])
            VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
                CardStrip(cards:question.hero,label:"Ваши карты · BTN (кнопка)")
                CardStrip(cards:question.board,label:"Общие карты · ривер")
            }
            .padding(AppTheme.Measure.d16)
            .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppTheme.radius))
            Text("Банк до ставки BB: \(question.potBefore). Ставка BB: \(question.opponentBet) all-in. Банк сейчас: \(question.potBefore+question.opponentBet). Колл: \(question.callAmount).")
                .accessibilityIdentifier("ev.amounts")
                .font(.subheadline)
            MetricStrip(items:[("До ставки","\(question.potBefore)"),("В банке","\(question.potBefore+question.opponentBet)"),("Колл","\(question.callAmount)")])
            Text("После колла оба all-in; при ничьей банк делится поровну.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            Text("Диапазон BB после ставки").font(.headline)
            ForEach(question.range,id:\.id) { hand in
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    CardStrip(cards:hand.cards)
                    VStack(alignment:.leading,spacing:AppTheme.Measure.d3) {
                        Text("Вес \(hand.weight) / \(result.totalWeight)").font(.subheadline.weight(.medium))
                        SwiftUI.ProgressView(value:Double(hand.weight),total:Double(result.totalWeight)).tint(AppTheme.accent)
                        Text("\(String(format:"%.1f",100*Double(hand.weight)/Double(result.totalWeight))) % в модели").font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(AppTheme.Measure.d12)
                .background(AppTheme.surfaceAlt,in:RoundedRectangle(cornerRadius:AppTheme.Measure.d12))
            }
            Text("Заданная equity Hero: \(String(format:"%.2f",result.equityPercent)) %. Она вычислена точно для показанного списка рук и весов, включая ничьи.")
                .accessibilityIdentifier("ev.equity")
            EquityMeter(percent:result.equityPercent,caption:"Ваша equity против заданного диапазона")
            DisclosureGroup("Условия модели") {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    Text(EVCallQuestion.conditions)
                    Text(EVCallQuestion.scope)
                }.font(.footnote).foregroundStyle(AppTheme.muted)
            }
            if let review { feedback(review) }
            else {
                Text("Выберите действие с большим EV. При равенстве подходят оба варианта.").font(.headline)
                ForEach(EVDecision.allCases,id:\.self) { decision in
                    Button(decision.title) { choose(decision) }.buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("ev.answer.\(decision.rawValue)")
                }
            }
            DisclosureGroup("Модель и источник") {
                Text("Модель ev-call-v1 · 17.10.2026. Это собственные фиксированные диапазоны для расчёта. На ривере проверяются все перечисленные комбинации существующим evaluator; симуляция не используется. Предпосылки: уроки pot odds и equity.").font(.footnote)
                Link("Upswing Poker · Pot Odds Explained",destination:URL(string:"https://upswingpoker.com/pot-odds-step-by-step/")!)
            }
        }
    }
    private func feedback(_ review:EVCallAttempt) -> some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Text(review.isCorrect ? "Верно по модели" : "Сравним ожидаемую ценность").font(.headline)
            Text("Ваш выбор: \(review.decision.title)")
            Text("EV(Call): \(result.signedEV) · EV(Fold): 0,00 фишки")
                .accessibilityIdentifier("ev.values")
            EVComparisonDiagram(callEV:result.callEV,callCost:Double(question.callAmount))
            OutcomeDistribution(wins:result.weightedWins,ties:result.weightedTies,losses:result.weightedLosses,weighted:true)
            FormulaSteps(lines:[
                "Банк после колла: \(question.finalPot) фишек",
                "Порог колла: \(String(format:"%.2f",question.thresholdPercent)) %",
                "EV(Call): \(result.signedEV) фишки · EV(Fold): 0,00"
            ])
            Text(result.recommendation).font(.subheadline.weight(.semibold))
            DisclosureGroup("Подробнее о расчёте") {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    ForEach(result.explanation(potBefore:question.potBefore,opponentBet:question.opponentBet),id:\.self) { Text($0) }
                }.font(.footnote).foregroundStyle(AppTheme.muted)
            }
            if saved {
                Text("Результат сохранён на устройстве.").foregroundStyle(AppTheme.success)
                Button(index+1 == EVCallQuestion.examples.count ? "Завершить урок" : "Следующий сценарий") {
                    completed.append(review)
                    if index+1 == EVCallQuestion.examples.count { finished=true }
                    else { self.review=nil;saved=false;saveError=nil;index+=1 }
                }.buttonStyle(PrimaryButtonStyle())
            } else {
                if let saveError { ErrorNotice(text:saveError) }
                Button("Повторить сохранение") { save() }.buttonStyle(SecondaryButtonStyle())
            }
        }
    }
    private func choose(_ decision:EVDecision) {
        guard review == nil else { return }
        do { review=try EVCallAttempt(question:question,decision:decision);save() }
        catch { saveError="Ответ обработать не удалось: \(error.localizedDescription)" }
    }
    private func save() {
        guard let review,!saved else { return }
        do { try store.record(review);saved=true;saveError=nil }
        catch { saveError="Ответ проверен. Сохранить пока не удалось: \(error.localizedDescription)" }
    }
}
