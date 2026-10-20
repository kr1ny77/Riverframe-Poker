import SwiftUI
import PokerCore

struct OutsLessonView: View {
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.dismiss) private var dismiss
    @State private var index=0
    @State private var review: PracticeAttempt?
    @State private var saved=false
    @State private var saveError: String?
    @State private var finished=false
    @State private var runAttempts: [PracticeAttempt]=[]
    private let lesson=FlushDrawLesson.standard
    private var question: FlushDrawQuestion { lesson.questions[index] }

    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
                LessonHeader(title:"Ауты флеш-дро",detail:"Точный перебор без приближений")
                if finished { summary }
                else {
                    MetricStrip(items:[("Шаг","\(index+1) из \(lesson.questions.count)"),("Аутов","9"),("Метод","Точный перебор")])
                    context
                    Text("Из 47 неизвестных карт девять червей завершают флеш.")
                        .font(.subheadline)
                    DisclosureGroup("Показать ауты") {
                        Text(lesson.outs.map { $0.rankLabel+$0.symbol }.joined(separator:", "))
                            .accessibilityLabel(lesson.outs.map(\.label).joined(separator:", "))
                    }
                    Text(question.prompt).font(.headline)
                    if let review {
                        feedback(review)
                    } else {
                        ForEach(question.choices,id:\.self) { choice in
                            Button { choose(choice) } label: {
                                Text("\(percent(choice)) %").frame(maxWidth:.infinity)
                            }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    DisclosureGroup("Допущения расчёта") {
                        Text(question.modelNote)
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                    }
                }
            }.padding()
        }.lessonCanvas()
        .navigationTitle("Ауты")
    }
    private var context: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
            MetricStrip(items:[("Hero","BTN"),("Соперник","BB"),("Стеки","100 BB")])
            CardStrip(cards:lesson.hero,label:"Ваши карты")
            CardStrip(cards:lesson.flop,label:"Флоп")
        }.padding().frame(maxWidth:.infinity,alignment:.leading)
            .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppTheme.radius))
    }
    private func feedback(_ attempt:PracticeAttempt) -> some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d12) {
            Label(attempt.isCorrect ? "Верно по условию" : "Разберём расчёт",systemImage:attempt.isCorrect ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.headline).foregroundStyle(attempt.isCorrect ? AppTheme.success : AppTheme.warning)
            MetricStrip(items:[("Ваш ответ","\(percent(attempt.answer)) %"),("Точный ответ","\(percent(question.correctPercent)) %"),("Аутов","9 / 47")])
            EquityMeter(percent:question.correctPercent,caption:question.horizon == .nextCard ? "На следующей карте" : "К риверу",title:"Вероятность флеша",accessibilityName:"Вероятность собрать флеш")
            FormulaSteps(lines:Array(question.explanation.prefix(3)))
            DisclosureGroup("Подробнее о расчёте") {
                VStack(alignment:.leading,spacing:AppTheme.Measure.d8) {
                    ForEach(Array(question.explanation.dropFirst(3).enumerated()),id:\.offset) { step in
                        Text(step.element)
                    }
                }.font(.footnote).foregroundStyle(AppTheme.muted)
            }
            if saved {
                Text("Ответ сохранён на устройстве.").font(.footnote).foregroundStyle(AppTheme.success)
                Button(index+1 == lesson.questions.count ? "Завершить урок" : "К вероятности к риверу") { advance() }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                if let saveError { ErrorNotice(text:saveError) }
                Button("Повторить сохранение") { saveReview() }.buttonStyle(SecondaryButtonStyle())
            }
        }.padding().frame(maxWidth:.infinity,alignment:.leading)
            .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppTheme.radius))
            .accessibilityElement(children:.contain)
    }
    private var summary: some View {
        VStack(alignment:.leading,spacing:AppTheme.Measure.d16) {
            Text("Набор завершён").font(.title2.bold())
            MetricStrip(items:[("Верно","\(runAttempts.filter(\.isCorrect).count) из \(runAttempts.count)"),("Тёрн","9 / 47 ≈ 19,1 %"),("К риверу","378 / 1 081 ≈ 35,0 %")])
            Text("Это вероятность собрать флеш при указанных допущениях. Качество игрового решения и результат раздачи оцениваются отдельно.")
                .foregroundStyle(AppTheme.muted)
            CourseFinishView(lesson:.outs)
            Button("Пройти урок ещё раз") {
                index=0;review=nil;saved=false;saveError=nil;finished=false;runAttempts=[]
            }.buttonStyle(PrimaryButtonStyle())
            Button("К темам",action:{dismiss()}).buttonStyle(SecondaryButtonStyle())
        }
    }
    private func choose(_ answer:Double) {
        guard review==nil else { return }
        review=PracticeAttempt(question:question,answer:answer)
        saveReview()
    }
    private func saveReview() {
        guard let review,!saved else { return }
        do { try store.record(review);saved=true;saveError=nil }
        catch { saveError="Ответ проверен. Записать результат пока не удалось: \(error.localizedDescription)" }
    }
    private func advance() {
        guard saved,let review else { return }
        runAttempts.append(review)
        if index+1==lesson.questions.count { finished=true }
        else { index+=1;self.review=nil;saved=false;saveError=nil }
    }
    private func percent(_ value:Double) -> String {
        String(format:"%.1f",value).replacingOccurrences(of:".",with:",")
    }
}
