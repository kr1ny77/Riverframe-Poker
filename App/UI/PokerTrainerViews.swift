import SwiftUI
import PokerCore

enum AppTheme {
    static let bg = Color("bg")
    static let surface = Color("surface")
    static let surfaceAlt = Color("surface-alt")
    static let text = Color("text")
    static let muted = Color("text-muted")
    static let accent = Color("accent")
    static let onAccent = Color("on-accent")
    static let border = Color("border")
    static let danger = Color("danger")
    static let success = Color("success")
    static let warning = Color("warning")
    static let table = Color("table-bg")
    static let cardInk = Color("card-ink")
    static let cardRed = Color("card-red")
    static let accentPressed = Color("accent-pressed")
    static let borderInput = Color("border-input")
    static let cardFace = Color("card-face")
    static let tableText = Color("table-text")
    static let tableMuted = Color("table-muted")
    static let tableSurface = Color("table-surface")
    static let tableAccent = Color("table-accent")
    static let radius: CGFloat = 20
    enum Measure {
        static let d0: CGFloat = 0
        static let d1: CGFloat = 1
        static let d2: CGFloat = 2
        static let d3: CGFloat = 3
        static let d6: CGFloat = 6
        static let d7: CGFloat = 7
        static let d8: CGFloat = 8
        static let d10: CGFloat = 10
        static let d12: CGFloat = 12
        static let d16: CGFloat = 16
        static let d18: CGFloat = 18
        static let d20: CGFloat = 20
        static let d24: CGFloat = 24
        static let d32: CGFloat = 32
        static let d40: CGFloat = 40
        static let d30: CGFloat = 30
        static let d48: CGFloat = 48
    }
    enum Metrics {
        static let lessonReadingWidth: CGFloat = 760
        static let compactWidth: CGFloat = 340
        static let panelSpacing: CGFloat = 12
        static let tableRadius: CGFloat = 24
        static let textureOpacity: Double = 0.12
        static let boardCard = CGSize(width: 42, height: 59)
        static let heroCard = CGSize(width: 48, height: 67)
        static let opponentCard = CGSize(width: 20, height: 28)
        static let actionHeight: CGFloat = 48
    }
}

private extension Color {
    init(hex: String) {
        let source = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(source, radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}

struct AppShellView: View {
    @EnvironmentObject private var game: GameViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { PlayHomeView() }
                .tabItem { Label("Играть", systemImage: "suit.spade.fill") }.tag(0)
            NavigationStack { TrainingHomeView() }
                .tabItem { Label("Тренировка", systemImage: "brain.head.profile") }.tag(1)
            NavigationStack { ProgressView() }
                .tabItem { Label("Прогресс", systemImage: "chart.bar.fill") }.tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }.tag(3)
        }
        .tint(AppTheme.accent)
        .opaqueTabBar()
        .onChange(of: selectedTab) { _, tab in if tab != 0 { game.setPaused(true) } }
        .onChange(of: scenePhase) { _, phase in game.handleScenePhase(phase) }
    }
}

struct PlayHomeView: View {
    @EnvironmentObject private var game: GameViewModel
    @EnvironmentObject private var store: PracticeStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d32) {
                StudioHeading(title: "RiverFrame", subtitle: "Покер начинается с решения")
                VStack(alignment: .leading, spacing: AppTheme.Measure.d20) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Практика за столом").font(.title2.weight(.bold))
                        Spacer(minLength: AppTheme.Measure.d8)
                        Image(systemName: "suit.spade.fill").font(.title2).accessibilityHidden(true)
                    }
                    HStack(alignment: .center, spacing: AppTheme.Measure.d20) {
                        HStack(spacing: AppTheme.Measure.d6) {
                            PlayingCardView(card: Card(id: 48), size: CGSize(width: 48, height: 67))
                            PlayingCardView(card: Card(id: 45), size: CGSize(width: 48, height: 67))
                        }.accessibilityLabel("Демонстрационные карты")
                        VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                            Text("Вы и пять ботов").font(.headline)
                            Text("Блайнды 5 / 10").font(.subheadline.monospacedDigit())
                            Text(game.activeBotLevel.title).font(.subheadline.weight(.medium))
                                .accessibilityLabel("Учебный профиль: " + game.activeBotLevel.title)
                                .accessibilityIdentifier("table.activeBotLevel")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if game.selectedBotLevel != game.activeBotLevel {
                        Text("Со следующей раздачи: " + game.selectedBotLevel.title).font(.footnote)
                    }
                    NavigationLink { TableView() } label: {
                        Text(game.snapshot.complete ? "Результат раздачи" : "Открыть стол")
                            .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.actionHeight)
                            .font(.headline)
                    }
                    .buttonStyle(.plain).foregroundStyle(AppTheme.tableSurface)
                    .background(AppTheme.tableText, in: RoundedRectangle(cornerRadius: AppTheme.Measure.d12))
                }
                .padding(AppTheme.Measure.d24)
                .foregroundStyle(AppTheme.tableText)
                .background(AppTheme.table, in: RoundedRectangle(cornerRadius: AppTheme.Metrics.tableRadius))

                WorkbenchSection(title: "Вернуться к обучению") {
                    CourseNextStepView()
                    NavigationLink { TrainingHomeView() } label: {
                        NavigationRow(title: "Короткая тренировка", subtitle: "Курс из 60 тем и отдельные задачи", symbol: "books.vertical")
                    }.buttonStyle(.plain)
                }
                HStack(alignment: .top, spacing: AppTheme.Measure.d12) {
                    Image(systemName: "iphone").font(.headline)
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
                        Text("Практика офлайн").font(.subheadline.weight(.medium))
                        Text("Виртуальные фишки. Учитесь в своём темпе.").font(.footnote).foregroundStyle(AppTheme.muted)
                    }
                }
                DisclosureGroup("Как устроены боты") {
                    Text("Все пять ботов используют один учебный профиль. Эвристики меняют выбор рук и реакцию на ставки. Условия решений можно разобрать в курсе.")
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(maxWidth: AppTheme.Metrics.lessonReadingWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Measure.d20)
            .padding(.bottom, AppTheme.Measure.d24)
        }.lessonCanvas().navigationTitle("Играть")
    }
}

enum BetEditorKind: String, Identifiable { case raise, allIn; var id: String { rawValue } }

struct BetEditor: View {
    let kind: BetEditorKind
    let snapshot: GameSnapshot
    let submit: (PokerAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var amountFocused:Bool

    private var legal: LegalActions { snapshot.legal }
    private var minimum: Int64 { legal.minRaiseTo ?? legal.maxRaiseTo }
    private var maximum: Int64 { legal.maxRaiseTo }
    private var amount: Int64? {
        let stripped = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
        guard !stripped.isEmpty, stripped.allSatisfy(\.isNumber) else { return nil }
        return Int64(stripped)
    }
    private var inputError: String? {
        guard kind == .raise else { return nil }
        let stripped = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
        if stripped.isEmpty { return "Введите целое число фишек." }
        if !stripped.allSatisfy(\.isNumber) { return "Разрешены только целые фишки и пробелы-разделители." }
        guard let amount else { return "Сумма слишком велика." }
        if amount < minimum { return "Минимум: \(minimum)." }
        if amount > maximum { return "Максимум: \(maximum)." }
        return nil
    }
    private var valid: Bool { guard let amount else { return false }; return amount >= minimum && amount <= maximum }

    var body: some View {
        NavigationStack {
            Form {
                Section(kind == .allIn ? "Олл-ин" : (snapshot.currentBet == 0 ? "Ставка" : "Повысить до")) {
                    Text("Банк: \(snapshot.pot)")
                    Text("Допустимо: \(minimum)–\(maximum) фишек")
                    if kind == .allIn {
                        Text("Всего на этой улице: \(maximum)")
                        Text("Сейчас в банк: \(maximum - (snapshot.players.first(where: { $0.id == 0 })?.contribution ?? 0))")
                        Text("Олл-ин отправит все доступные фишки. Проверьте сумму перед подтверждением.").foregroundStyle(AppTheme.muted)
                    }
                }.listRowBackground(AppTheme.surface)
                if kind == .raise {
                    Section("Всего на этой улице") {
                        TextField("Сумма", text: $text,prompt:Text("Сумма").foregroundStyle(AppTheme.muted)).numericKeyboard().focused($amountFocused).lessonInput()
                        if let error = inputError { Text(error).font(.footnote).foregroundStyle(AppTheme.danger) }
                        if let amount, valid {
                            Text("Сейчас в банк: \(amount - (snapshot.players.first(where: { $0.id == 0 })?.contribution ?? 0))")
                                .font(.subheadline.monospacedDigit()).accessibilityIdentifier("bet.pay-now")
                        }
                        HStack {
                            if let half = suggested(0.5) { quickButton("½ банка", value: half) }
                            if let full = suggested(1.0) { quickButton("Банк", value: full) }
                        }
                    }.listRowBackground(AppTheme.surface)
                }
            }
            .scrollContentBackground(.hidden).background(AppTheme.bg)
            .navigationTitle("Ставка")
            .lessonCanvas()
            .lessonKeyboardToolbar { amountFocused=false }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Подтвердить") {
                        let target = kind == .allIn ? maximum : amount ?? 0
                        submit(kind == .allIn ? .allIn : .raiseTo(target))
                    }.disabled(kind == .allIn ? !legal.canAllIn : !valid)
                }
            }
            .onAppear { text = String(kind == .allIn ? maximum : minimum) }
        }
    }

    private func suggested(_ fraction: Double) -> Int64? {
        let contribution = snapshot.players.first(where: { $0.id == 0 })?.contribution ?? 0
        let total = Double(contribution + legal.callAmount) + (Double(snapshot.pot + legal.callAmount) * fraction)
        let target = Int64(total.rounded())
        return (minimum...maximum).contains(target) ? target : nil
    }
    private func quickButton(_ label: String, value: Int64) -> some View { Button(label) { text = String(value) }.buttonStyle(.bordered) }
}

struct OutcomeView: View {
    let snapshot: GameSnapshot
    let next: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Text("Раздача завершена").font(.title3.bold())
            Text(snapshot.result.isEmpty ? "Результат определён правилами стола." : snapshot.result)
            ForEach(snapshot.log.suffix(4), id: \.self) { Text($0).font(.caption).foregroundStyle(AppTheme.muted) }
            Button("Следующая раздача", action: next).buttonStyle(PrimaryButtonStyle())
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
    }
}

struct TrainingHomeView: View {
    var body: some View { LearningCourseHomeView() }
}

struct PotOddsExerciseView: View {
    let question: PotOddsQuestion
    var onContinue: (() -> Void)? = nil
    @EnvironmentObject private var store: PracticeStore
    @State private var answer = ""
    @FocusState private var answerFocused:Bool
    @State private var reviewed = false
    @State private var saved = false
    @State private var saveError: String?
    @State private var pendingAttempt: PracticeAttempt?

    private var value: Double? { Double(answer.replacingOccurrences(of: ",", with: ".")) }
    private var correct: Bool { guard let value else { return false }; return abs(value - question.correctPercent) <= 0.5 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d18) {
                LessonHeader(title:"Шансы банка",detail:"Какая доля банка нужна, чтобы оплатить колл?")
                OddsDiagram(pot:question.potBefore,bet:question.opponentBet)
                Text("Equity — средняя доля банка. Введите её минимальный процент для колла.").font(.subheadline).foregroundStyle(AppTheme.muted)
                TextField("Процент", text: $answer,prompt:Text("Процент").foregroundStyle(AppTheme.muted)).decimalKeyboard().focused($answerFocused).lessonInput().disabled(reviewed)
                if !answer.isEmpty && !isValidAnswer && !reviewed { Text("Введите число от 0 до 100.").font(.footnote).foregroundStyle(AppTheme.danger) }
                if !reviewed {
                    Button("Проверить") { recordAnswer() }.buttonStyle(PrimaryButtonStyle()).disabled(!isValidAnswer)
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d10) {
                        Label(correct ? "Верно по условию" : "Разберём решение", systemImage: correct ? "checkmark.circle.fill" : "info.circle.fill")
                            .foregroundStyle(correct ? AppTheme.success : AppTheme.danger).font(.headline)
                        Text("Ваш ответ: \(answer)%. Нужно для колла: \(format(question.correctPercent))%")
                        EquityMeter(percent:question.correctPercent,caption:"Минимальная доля банка для колла")
                        DisclosureGroup("Подробнее о расчёте") { FormulaSteps(lines:question.explanation).padding(.top,12) }
                        if saved {
                            Text("Результат сохранён на устройстве.").foregroundStyle(AppTheme.success)
                            if let onContinue { Button("Продолжить курс",action:onContinue).buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("pot-odds.next") }
                        }
                    }.padding().background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                }
                if let saveError {
                    ErrorNotice(text: saveError)
                    Button("Повторить сохранение") { saveReview() }.buttonStyle(SecondaryButtonStyle())
                }
            }.padding()
        }.background(AppTheme.bg).navigationTitle("Упражнение").inlineNavigationTitle()
            .lessonKeyboardToolbar { answerFocused=false }
    }

    private func recordAnswer() {
        guard !reviewed, isValidAnswer, let value else { return }
        answerFocused=false
        pendingAttempt = PracticeAttempt(question: question, answer: value)
        reviewed = true
        saveReview()
    }
    private func saveReview() {
        guard let pendingAttempt, !saved else { return }
        do {
            try store.record(pendingAttempt)
            saved = true
            saveError = nil
        } catch {
            saveError = "Ответ проверен. Результат пока не сохранён: \(error.localizedDescription)"
        }
    }
    private var isValidAnswer: Bool { guard let value else { return false }; return value.isFinite && (0...100).contains(value) }
    private func format(_ value: Double) -> String { String(format: "%.1f", value) }
}

struct ProgressView: View {
    @EnvironmentObject private var store: PracticeStore
    var body: some View {
        List {
            if let error = store.errorMessage {
                Section { ErrorNotice(text: error); Button("Повторить загрузку") { store.reload() } }
            }
            Section {
                StudioHeading(title: "Ваш путь", subtitle: "Решения, понятия и следующая проверка")
            }.listRowBackground(AppTheme.bg)
            CatalogProgressSection()
            CourseProgressSection()
            Section {
                NavigationLink { LegacyProgressHistoryView() } label: {
                    NavigationRow(title: "История ответов", subtitle: "Прежние наборы и подробные результаты", symbol: "clock.arrow.circlepath")
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(AppTheme.bg)
        .lessonCanvas().navigationTitle("Прогресс")
        .navigationDestination(for: CourseLessonID.self) { CourseLessonDestination(lesson: $0) }
    }
}

private struct LegacyProgressHistoryView: View {
    @EnvironmentObject private var store: PracticeStore
    var body: some View {
        List {
            Group {
            if let error = store.errorMessage {
                Section { ErrorNotice(text: error); Button("Повторить загрузку") { store.reload() } }
            }
            CourseProgressSection()
            CatalogProgressSection()
            if store.attempts.isEmpty && store.comparisons.isEmpty && store.positions.isEmpty && store.evCalls.isEmpty && store.blockers.isEmpty && store.foundations.isEmpty {
                ContentUnavailableView("Пока нет попыток", systemImage: "chart.bar", description: Text("Результаты упражнений появятся здесь после проверки ответа."))
            } else {
                if !store.blockers.isEmpty {
                    Section("Комбинаторика и блокеры") {
                        Text("Верно \(store.blockers.filter(\.isCorrect).count) из \(store.blockers.count) ответов по модели")
                            .accessibilityIdentifier("progress.blockers")
                    }
                    Section("История комбинаторики") {
                        ForEach(store.blockers.reversed()) { attempt in
                            if let question=attempt.question {
                                VStack(alignment:.leading) {
                                    Text(attempt.isCorrect ? "Верно по модели" : "Повторить подсчёт").font(.headline)
                                    Text(question.prompt)
                                    Text("Ответ: \(question.choiceTitle(attempt.answerIndex))").font(.caption).foregroundStyle(AppTheme.muted)
                                }
                            }
                        }
                    }
                }
                if !store.evCalls.isEmpty {
                    Section("EV колла и фолда") {
                        Text("Верно \(store.evCalls.filter(\.isCorrect).count) из \(store.evCalls.count) решений по модели")
                            .accessibilityIdentifier("progress.ev-call")
                        Text("Оценка выбора Call/Fold при заданных диапазонах; результат раздачи в оценку не входит.")
                    }
                    Section("История решений EV") {
                        ForEach(store.evCalls.reversed()) { attempt in
                            if let question=attempt.question {
                                VStack(alignment:.leading) {
                                    Text(attempt.isCorrect ? "Верно по модели" : "Повторить сравнение EV").font(.headline)
                                    Text("\(attempt.decision.title) · EV(Call) \(question.result.signedEV) · EV(Fold) 0,00")
                                    Text("Ривер · BTN против BB").font(.caption).foregroundStyle(AppTheme.muted)
                                }
                            }
                        }
                    }
                }
                ForEach(LearningTopic.allCases.filter { topic in store.attempts.contains { $0.topic == topic } }) { topic in
                    let attempts = store.attempts.filter { $0.topic == topic }
                    Section(topic.title) {
                        Text("Верно \(attempts.filter(\.isCorrect).count) из \(attempts.count) ответов по ключу").monospacedDigit()
                    }
                }
                if !store.positions.isEmpty {
                    Section("Позиции и стартовые руки") {
                        Text("Верно \(store.positions.filter(\.isCorrect).count) из \(store.positions.count) ответов по условию")
                            .accessibilityIdentifier("progress.positions")
                    }
                    Section("История позиций") {
                        ForEach(store.positions.reversed()) { attempt in
                            if let question=attempt.question {
                                VStack(alignment:.leading) {
                                    Text(attempt.isCorrect ? "Верно по условию" : "Разбор понятия").font(.headline)
                                    Text(question.prompt)
                                    Text(question.choices[attempt.answerIndex]).font(.caption).foregroundStyle(AppTheme.muted)
                                }
                            }
                        }
                    }
                }
                if !store.comparisons.isEmpty {
                    Section("Комбинации и сравнение рук") {
                        Text("Верно \(store.comparisons.filter(\.isCorrect).count) из \(store.comparisons.count) ответов по ключу")
                            .monospacedDigit().accessibilityIdentifier("progress.combinations")
                        Text("Выбор победителя: \(store.comparisons.filter { $0.question.mode == .winner && $0.isCorrect }.count) из \(store.comparisons.filter { $0.question.mode == .winner }.count)")
                        Text("Лучшая пятёрка: \(store.comparisons.filter { $0.question.mode == .bestFive && $0.isCorrect }.count) из \(store.comparisons.filter { $0.question.mode == .bestFive }.count)")
                    }
                    Section("История комбинаций") {
                        ForEach(store.comparisons.reversed()) { attempt in
                            VStack(alignment:.leading) {
                                Text(attempt.isCorrect ? "Верно по картам" : "Разбор сравнения").font(.headline)
                                Text(attempt.question.mode == .winner ? "Выбор победителя" : "Лучшая пятёрка игрока A")
                                Text("A: \(attempt.question.firstRank.title) · B: \(attempt.question.secondRank.title)")
                                    .font(.caption).foregroundStyle(AppTheme.muted)
                                Text(attempt.date,style:.date).font(.caption).foregroundStyle(AppTheme.muted)
                            }
                        }
                    }
                }
                Section("История") { ForEach(store.attempts.reversed()) { attempt in
                    VStack(alignment: .leading) { Text(attempt.topic.title).font(.headline); Text(attempt.isCorrect ? "Верно" : "Разбор решения"); Text("Ваш ответ \(String(format: "%.1f", attempt.answer))% · ключ \(String(format: "%.1f", attempt.correctPercent))%").font(.caption).foregroundStyle(AppTheme.muted) }
                } }
            }
            }.listRowBackground(AppTheme.bg)
        }.listStyle(.plain).scrollContentBackground(.hidden).background(AppTheme.bg).navigationTitle("Прогресс").lessonCanvas()
            .navigationDestination(for:CourseLessonID.self) { CourseLessonDestination(lesson:$0) }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var game: GameViewModel
    @EnvironmentObject private var store: PracticeStore
    @State private var confirmClear = false
    var body: some View {
        Form {
            Group {
            Section {
                StudioHeading(title: "Ваша практика", subtitle: "Условия стола и данные на устройстве")
            }
            Section("Учебный стол") {
                LabeledContent("Формат", value: "6-max")
                LabeledContent("Блайнды", value: "5 / 10")
            }
            Section("Все пять ботов") {
                Picker("Учебный профиль ботов", selection: Binding(get: { game.selectedBotLevel }, set: { game.selectBotLevel($0) })) {
                    ForEach(BotLevel.allCases, id: \.self) { level in Text(level.title).tag(level) }
                }.accessibilityIdentifier("settings.botLevel")
                Text(game.selectedBotLevel.learningDescription).font(.subheadline).foregroundStyle(AppTheme.muted)
                Label("Новый профиль — со следующей раздачи", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            Section("На вашем устройстве") {
                Label("Курс и результаты доступны офлайн", systemImage: "iphone")
                Text("Виртуальные фишки используются для практики. Результаты упражнений сохраняются локально.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            Section("Прогресс") { Button("Очистить результаты", role: .destructive) { confirmClear = true }.foregroundStyle(AppTheme.danger) }
            if let error = store.errorMessage {
                Section("Хранилище") { ErrorNotice(text: error); Button("Повторить загрузку") { store.reload() } }
            }
            }.listRowBackground(AppTheme.surface)
        }.scrollContentBackground(.hidden).background(AppTheme.bg).navigationTitle("Настройки").lessonCanvas()
        .alert("Очистить результаты?", isPresented: $confirmClear) {
            Button("Очистить", role: .destructive) { do { try store.clear() } catch {} }
            Button("Отмена", role: .cancel) {}
        } message: { Text("Будут удалены сохранённые результаты упражнений на этом устройстве.") }
    }
}

struct ErrorNotice: View { let text: String; var body: some View { Label(text, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(AppTheme.danger).padding().frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.Measure.d12)) } }
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.font(.body.weight(.semibold)).multilineTextAlignment(.center)
            .frame(maxWidth:.infinity,minHeight:48).padding(.horizontal,14)
            .foregroundStyle(enabled ? AppTheme.onAccent : AppTheme.muted)
            .background(!enabled ? AppTheme.surfaceAlt : (configuration.isPressed ? AppTheme.accentPressed : AppTheme.accent),in:RoundedRectangle(cornerRadius:12))
            .opacity(1)
    }
}
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.font(.body.weight(.medium)).multilineTextAlignment(.center)
            .frame(maxWidth:.infinity,minHeight:48).padding(.horizontal,12)
            .foregroundStyle(AppTheme.text)
            .background(configuration.isPressed ? AppTheme.surfaceAlt : AppTheme.surface,in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border,lineWidth:1))
            .opacity(1)
    }
}
struct DarkGroupBoxStyle: GroupBoxStyle { func makeBody(configuration: Configuration) -> some View { VStack(alignment: .leading, spacing: AppTheme.Measure.d8) { configuration.label.font(.headline); configuration.content }.padding().background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius)) } }

extension View {
    @ViewBuilder func opaqueTabBar() -> some View {
        #if os(iOS)
        self.toolbarBackground(AppTheme.bg,for:.tabBar).toolbarBackground(.visible,for:.tabBar)
        #else
        self
        #endif
    }
    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.bg,for:.navigationBar,.tabBar)
            .toolbarBackground(.visible,for:.navigationBar,.tabBar)
        #else
        self
        #endif
    }

    @ViewBuilder func numericKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
