import SwiftUI
import PokerCore

/// A task session owns one frozen attempt. Save retry reuses its UUID.
struct FoundationLessonView: View {
    let exercise: FoundationExercise
    @EnvironmentObject private var store: PracticeStore
    @FocusState private var answerFocused: Bool
    @State private var started = false
    @State private var number = ""
    @State private var selection: Int?
    @State private var checked: FoundationAttempt?
    @State private var saved = false
    @State private var error: String?
    private var latest: FoundationAttempt? {
        store.foundations.filter { $0.exerciseID == exercise.id && $0.contentVersion == exercise.contentVersion }.sorted { $0.date < $1.date }.last
    }
    private var response: FoundationResponse? {
        switch exercise.answer {
        case .number:
            guard let value = Double(number.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
            return .number(value)
        case .choice: return selection.map(FoundationResponse.choice)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d20) {
                LessonHeader(title: exercise.title, detail: exercise.topicID.rawValue + " · " + exercise.purpose.title)
                Text(exercise.resultKind.title).font(.subheadline.weight(.medium))
                if let simulation = exercise.simulation {
                    CourseSimulationPanel(report: simulation)
                }
                if !started {
                    Text("Цель: применить «" + exercise.term + "» к заданной ситуации.").font(.headline)
                    if let latest {
                        Text(latest.isCorrect ? "Последний ответ: верно по условию." : "Последний ответ: есть ошибка.")
                            .font(.headline).accessibilityIdentifier("foundation.restored-result")
                        Text(responseLabel(latest.response)).font(.subheadline)
                        Text(latest.date, format: .dateTime.day().month().year().hour().minute()).font(.footnote)
                        Text("Результат восстановлен из локальной истории.").font(.footnote)
                    }
                    Button(latest == nil ? "Перейти к задаче" : "Решить ещё раз") { started = true }
                        .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("foundation.start")
                    LessonTermBox(term: exercise.term, definition: exercise.definition, example: exercise.example)
                    LessonMethodBox(when: exercise.assumptions, steps: [exercise.method, "Проверьте единицы ответа и ограничения условия."])
                    Text(exercise.assumptions).font(.footnote).foregroundStyle(AppTheme.muted)
                } else {
                    task
                }
                if let message = store.errorMessage { ErrorNotice(text: message) }
                Text("ID: \(exercise.id.rawValue) · редакция \(exercise.contentVersion)")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: AppTheme.Metrics.lessonReadingWidth, alignment: .leading)
            .frame(maxWidth: .infinity).padding(AppTheme.Measure.d16)
        }
        .lessonCanvas().navigationTitle(exercise.topicID.rawValue)
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Готово") { answerFocused = false } } }
    }
    private var task: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d16) {
            ForEach(exercise.context, id: \.self) { Text($0) }
            if !exercise.cards.isEmpty { CardStrip(cards: exercise.cards, label: "Карты из условия") }
            if !exercise.chart.isEmpty {
                Text("Условная учебная таблица").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Measure.d8) {
                    ForEach(exercise.chart.indices, id: \.self) { index in
                        let cell = exercise.chart[index]
                        VStack(spacing: AppTheme.Measure.d6) {
                            Text(cell.label).font(.headline)
                            Text(cell.value).font(.footnote)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Measure.d12).background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                        .accessibilityElement(children: .ignore).accessibilityLabel(cell.label + ": " + cell.value)
                    }
                }.accessibilityIdentifier("foundation.chart")
            }
            Text(exercise.question).font(.headline).accessibilityIdentifier("foundation.question")
            switch exercise.answer {
            case .number:
                TextField("Числовой ответ", text: $number).textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation).focused($answerFocused).accessibilityIdentifier("foundation.answer")
                    .disabled(checked != nil)
                Text("Допуск: ±\(exercise.answer.tolerance.formatted(.number.locale(Locale(identifier: "ru_RU")))) в единицах условия.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            case .choice(let options, _):
                ForEach(options.indices, id: \.self) { index in
                    Button { selection = index } label: {
                        Label(options[index], systemImage: selection == index ? "checkmark.circle.fill" : "circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(SecondaryButtonStyle()).disabled(checked != nil)
                    .accessibilityIdentifier("foundation.choice.\(index)")
                }
            }
            if let checked {
                Text(checked.isCorrect ? "Верно по условию." : "Есть ошибка. Посмотрите разбор.")
                    .font(.headline).accessibilityIdentifier("foundation.grade")
                Text(responseLabel(checked.response)).font(.subheadline)
                Text("Проверяемый ответ: " + answerLabel(checked.expected, rounded: true)).font(.headline)
                    .accessibilityIdentifier("foundation.expected")
                if !exercise.diagram.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                        ForEach(exercise.diagram.indices, id: \.self) { index in
                            let row = exercise.diagram[index]
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline) { Text(row.label); Spacer(); Text(row.value).monospacedDigit() }
                                VStack(alignment: .leading) { Text(row.label); Text(row.value).monospacedDigit() }
                            }
                            .accessibilityElement(children: .ignore).accessibilityLabel(row.label + ": " + row.value)
                        }
                    }
                    .padding(AppTheme.Measure.d16)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                }
                FormulaSteps(lines: exercise.explanation)
                Text("Типичная ошибка").font(.headline)
                Text(exercise.typicalError)
                Text(exercise.assumptions).font(.footnote).foregroundStyle(AppTheme.muted)
                if saved {
                    Text("Результат сохранён на устройстве.").accessibilityIdentifier("foundation.saved")
                    Button("К результату") { started = false; self.checked = nil; number = ""; selection = nil; saved = false }
                        .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("foundation.result")
                    if let next = nextExercise {
                        NavigationLink { FoundationLessonView(exercise: next) } label: { Text("Следующая задача: " + next.title) }
                            .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("foundation.next")
                    }
                } else {
                    if let error { ErrorNotice(text: error) }
                    Button("Повторить сохранение") { save(checked) }.buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("foundation.retry")
                }
            } else {
                Button("Проверить") {
                    guard let response else { return }
                    let attempt = FoundationAttempt(exercise: exercise, response: response)
                    answerFocused = false; checked = attempt; save(attempt)
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(response == nil)
                .accessibilityIdentifier("foundation.check")
            }
        }
    }
    private var nextExercise: FoundationExercise? {
        let tasks = CourseCatalog.foundations(for: exercise.topicID)
        guard let index = tasks.firstIndex(where: { $0.id == exercise.id }), index + 1 < tasks.count else { return nil }
        return tasks[index + 1]
    }
    private func save(_ attempt: FoundationAttempt) {
        do { try store.record(attempt); saved = true; error = nil }
        catch { saved = false; self.error = "Запись не удалась. Повтор сохранит тот же ответ." }
    }
    private func responseLabel(_ response: FoundationResponse) -> String { "Ваш ответ: " + answerLabel(response) }
    private func answerLabel(_ response: FoundationResponse, rounded: Bool = false) -> String {
        switch response {
        case .number(let value):
            let tolerance = exercise.answer.tolerance
            let places = tolerance > 0 ? min(8, max(0, Int(ceil(-log10(tolerance))))) : 0
            let format = FloatingPointFormatStyle<Double>.number
                .precision(.fractionLength(rounded ? places...places : 0...12))
                .locale(Locale(identifier: "ru_RU"))
            return value.formatted(format)
        case .choice(let index):
            if case .choice(let options, _) = exercise.answer, options.indices.contains(index) { return options[index] }
            return "Вариант \(index + 1)"
        }
    }
}


private struct CourseSimulationPanel: View {
    let report: CourseMonteCarloReport
    private func value(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(4)).locale(Locale(identifier: "ru_RU")))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Text("Записанная демонстрация Монте-Карло").font(.headline)
            Text(report.method).font(.footnote)
            Text("Seed: \(report.seed) · N: \(report.samples)").font(.subheadline.monospacedDigit())
            Text("W/T/L: \(report.wins) / \(report.ties) / \(report.losses). Знаменатель среднего: \(report.samples) проб.")
                .font(.footnote)
            EquityMeter(percent: report.meanPercent,
                        caption: "Выплата за пробу: победа 1 банка, ничья 0,5, поражение 0.",
                        title: "Оценка средней доли банка")
            Text("SE: \(value(report.standardErrorPP)) п.п.")
            Text("Приближённый 95%-интервал: \(value(report.lower95Percent))–\(value(report.upper95Percent)) % банка.")
            Text("s² = Σ(X − среднее)² / (N − 1); SE = √(s² / N). Числа показаны с округлением до 0,0001. Интервал использует наблюдённую дисперсию и нормальное приближение; границы ограничены 0–100 %.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            Text("Погрешность относится к выборке при заданных картах. Ошибка исходной модели требует отдельной оценки.")
                .font(.footnote)
        }
        .padding(AppTheme.Measure.d16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .accessibilityIdentifier("foundation.monte-carlo")
    }
}
