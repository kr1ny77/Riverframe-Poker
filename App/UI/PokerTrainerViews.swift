import SwiftUI
import PokerCore

private struct TokenFile: Decodable { let color: [String: String] }
private enum DesignTokens {
    static let colors: [String: String] = {
        guard let url = Bundle.main.url(forResource: "design-tokens", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(TokenFile.self, from: data) else { return [:] }
        return file.color
    }()
    static func color(_ name: String, fallback: String) -> Color { Color(hex: colors[name] ?? fallback) }
}

enum AppTheme {
    static let bg = DesignTokens.color("bg", fallback: "101A1D")
    static let surface = DesignTokens.color("surface", fallback: "19272B")
    static let surfaceAlt = DesignTokens.color("surface-alt", fallback: "24383D")
    static let text = DesignTokens.color("text", fallback: "F2F2E9")
    static let muted = DesignTokens.color("text-muted", fallback: "ADBDBE")
    static let accent = DesignTokens.color("accent", fallback: "D7B98C")
    static let onAccent = DesignTokens.color("on-accent", fallback: "101A1D")
    static let border = DesignTokens.color("border", fallback: "445C61")
    static let danger = DesignTokens.color("danger", fallback: "F2A0A3")
    static let success = DesignTokens.color("success", fallback: "93D0B5")
    static let warning = DesignTokens.color("warning", fallback: "D7B98C")
    static let table = DesignTokens.color("table-bg", fallback: "173D3D")
    static let cardInk = DesignTokens.color("card-ink", fallback: "19272B")
    static let cardRed = DesignTokens.color("card-red", fallback: "A3283D")
    static let accentPressed = DesignTokens.color("accent-pressed", fallback: "C2A275")
    static let borderInput = DesignTokens.color("border-input", fallback: "91AAAF")
    static let cardFace = DesignTokens.color("card-face", fallback: "FFFFFF")
    static let radius: CGFloat = 16
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
        static let d30: CGFloat = 30
        static let d48: CGFloat = 48
    }
    enum Metrics {
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
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                LessonHeader(title:"Практика холдема",detail:"Учитесь принимать решения — за столом и в коротких задачах.")
                VStack(alignment:.leading,spacing:20) {
                    HStack {
                        VStack(alignment:.leading,spacing:6) {
                            Text("Ваш учебный стол").font(.title3.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
                            Text("NLHE, шесть мест").font(.subheadline).foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        Image(systemName:"suit.spade.fill").font(.title).foregroundStyle(AppTheme.accent).accessibilityHidden(true)
                    }
                    HStack(alignment:.bottom,spacing:8) {
                        PlayingCardView(card:Card(id:48),size:CGSize(width:52,height:73))
                        PlayingCardView(card:Card(id:45),size:CGSize(width:52,height:73))
                        Spacer()
                        VStack(alignment:.trailing,spacing:4) {
                            Text("5 / 10").font(.title2.weight(.semibold).monospacedDigit())
                            Text("Блайнды").font(.caption).foregroundStyle(AppTheme.muted)
                        }
                    }.accessibilityLabel("Демонстрация карт. Блайнды пять и десять.")
                    Text("Учебный профиль: \(game.activeBotLevel.title)")
                        .accessibilityIdentifier("table.activeBotLevel")
                    if game.selectedBotLevel != game.activeBotLevel {
                        Text("Со следующей раздачи: \(game.selectedBotLevel.title)").font(.footnote)
                    }
                    NavigationLink { TableView() } label: {
                        Label(game.snapshot.complete ? "Результат раздачи" : "Открыть стол",systemImage:"play.fill")
                    }.buttonStyle(PrimaryButtonStyle())
                }.padding(20).background(AppTheme.table,in:RoundedRectangle(cornerRadius:24))
                VStack(alignment:.leading,spacing:12) {
                    Text("Разобрать одно решение").font(.system(.title3,design:.serif).weight(.semibold))
                    Text("Комбинации, вероятности, диапазоны и цена колла. Ответьте, затем проверьте расчёт.").fixedSize(horizontal:false,vertical:true)
                        .foregroundStyle(AppTheme.muted)
                    NavigationLink { TrainingHomeView() } label: {
                        Label("Короткая тренировка",systemImage:"arrow.right.circle")
                    }.buttonStyle(SecondaryButtonStyle())
                }
                DisclosureGroup("Как устроены боты") {
                    Text("Все пять ботов используют общий учебный профиль. Уровни меняют выбор рук, реакцию на ставки и размеры ставок по условным эвристикам. Практикуйте решения и разбирайте их условия в уроках.")
                        .font(.subheadline).foregroundStyle(AppTheme.muted).padding(.top,8)
                }.font(.subheadline)
                Label("Офлайн · виртуальные фишки",systemImage:"iphone").font(.footnote).foregroundStyle(AppTheme.muted)
            }.padding(20).padding(.bottom,16)
        }.lessonCanvas().navigationTitle("Играть")
    }
}

struct TableView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var game: GameViewModel
    @State private var editor: BetEditorKind?

    var body: some View {
        let snapshot = game.snapshot
        GeometryReader { viewport in
        ScrollView {
            VStack(spacing: AppTheme.Measure.d12) {
                (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading,spacing:12)) : AnyLayout(HStackLayout())) {
                    VStack(alignment: .leading) {
                        Text("Раздача \(snapshot.handNumber)").font(.headline)
                        Text("Учебный профиль: \(game.activeBotLevel.title)").font(.caption)
                            .accessibilityIdentifier("table.botProfile")
                        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading,spacing:4)) : AnyLayout(HStackLayout(spacing:4))) {
                            Text(snapshot.street)
                            if let actor=snapshot.players.first(where:{ $0.id == snapshot.actor }) {
                                Text(actor.id == 0 ? "· Ваш ход" : "· \(actor.name)").font(.caption)
                            }
                        }.foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Button(game.isPaused ? "Продолжить" : "Пауза") { game.setPaused(!game.isPaused) }
                        .font(.subheadline.weight(.semibold)).padding(.horizontal,12).frame(minHeight:44).background(AppTheme.surfaceAlt,in:Capsule())
                }
                (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading,spacing:4)) : AnyLayout(HStackLayout())) {
                    Text("Блайнды 5 / 10")
                    Spacer()
                    Text("Виртуальные фишки")
                }.font(.caption).foregroundStyle(AppTheme.muted)
                if typeSize.isAccessibilitySize { sessionControls(snapshot) }
                PokerTableView(snapshot:snapshot,compact:viewport.size.height < 500)
                if snapshot.complete {
                    OutcomeView(snapshot: snapshot) { game.startFreshHand() }
                }
                if let error = game.errorMessage { ErrorNotice(text: error) }
            }.padding()
        }
        }
        .background(AppTheme.bg)
        .navigationTitle("Стол")
        .inlineNavigationTitle()
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize { sessionControls(snapshot) }
        }
        .onAppear { game.setPaused(false) }
        .onDisappear { game.setPaused(true) }
        .sheet(item: $editor) { kind in
            BetEditor(kind: kind, snapshot: snapshot) { game.send($0); editor = nil }
                .presentationDetents([.large])
        }
    }
    @ViewBuilder
    private func sessionControls(_ snapshot: GameSnapshot) -> some View {
        if !snapshot.complete {
            VStack(spacing: AppTheme.Measure.d8) {
                if game.isPaused {
                    Text("Раздача на паузе. Нажмите «Продолжить».").foregroundStyle(AppTheme.muted)
                    Button("Продолжить") { game.setPaused(false) }.buttonStyle(PrimaryButtonStyle())
                } else {
                    ActionBar(snapshot:snapshot,botThinking:game.isBotThinking,onAction:game.send,onBet:{ editor = $0 })
                }
            }.padding(.horizontal,16).padding(.vertical,10).frame(maxWidth:.infinity).background(AppTheme.bg)
        }
    }

}

struct PokerTableView: View {
    let snapshot: GameSnapshot
    var compact = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Group {
            if typeSize >= .xLarge || compact {
                VStack(spacing:16) {
                    bankAndBoard
                    ForEach(snapshot.players) { player in SeatView(player:player,isActor:player.id == snapshot.actor) }
                }.padding(16)
            } else {
                PokerRingLayout {
                    ForEach(snapshot.players) { player in SeatView(player:player,isActor:player.id == snapshot.actor) }
                    bankAndBoard
                }.frame(height:430)
            }
        }.frame(maxWidth:.infinity)
            .background {
                ZStack {
                    AppTheme.table
                    Image("poker-table-charcoal-cloth-v1").resizable(resizingMode:.tile).opacity(0.08).accessibilityHidden(true)
                    if !compact && typeSize < .xLarge {
                        Ellipse().stroke(AppTheme.accent.opacity(0.2),lineWidth:1).padding(.horizontal,24).padding(.vertical,35)
                    }
                }.clipShape(RoundedRectangle(cornerRadius:32))
            }
            .accessibilityElement(children:.contain)
            .accessibilityLabel("Покерный стол, банк \(snapshot.pot), \(snapshot.street)")
    }
    private var bankAndBoard: some View {
        VStack(spacing:8) {
            VStack(spacing:3) {
                Text("Банк · ставка \(snapshot.currentBet)").font(.caption).foregroundStyle(AppTheme.muted)
                Text("\(snapshot.pot)").font(.system(.title,design:.rounded).weight(.semibold).monospacedDigit())
            }.accessibilityElement(children:.combine)
            BoardView(cards:snapshot.board)
        }
    }
}

private struct PokerRingLayout: Layout {
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) -> CGSize {
        CGSize(width:proposal.width.flatMap { $0.isFinite ? max(0,$0) : nil } ?? 350,height:proposal.height.flatMap { $0.isFinite ? max(0,$0) : nil } ?? 430)
    }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let places:[CGPoint]=[CGPoint(x:0.5,y:0.80),CGPoint(x:0.15,y:0.77),CGPoint(x:0.15,y:0.30),CGPoint(x:0.5,y:0.14),CGPoint(x:0.85,y:0.30),CGPoint(x:0.85,y:0.77),CGPoint(x:0.5,y:0.46)]
        for (index,view) in subviews.enumerated() where index < places.count {
            let width:CGFloat=index == 6 ? max(0,bounds.width-36) : (index == 0 ? 124 : min(98,bounds.width*0.28))
            view.place(at:CGPoint(x:bounds.minX+bounds.width*places[index].x,y:bounds.minY+bounds.height*places[index].y),anchor:.center,proposal:ProposedViewSize(width:width,height:nil))
        }
    }
}

struct BoardView: View {
    let cards: [Card]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo:.body) private var width:CGFloat=40
    private var cardWidth:CGFloat { min(width,56) }
    var body: some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:cardWidth),spacing:6)],spacing:6) {
            ForEach(0..<5,id:\.self) { index in
                Group {
                    if index < cards.count { PlayingCardView(card:cards[index],size:CGSize(width:cardWidth,height:cardWidth*1.4))
                            .transition(.opacity.combined(with:.offset(y:reduceMotion ? 0 : 8))) }
                    else { RoundedRectangle(cornerRadius:7).stroke(AppTheme.muted.opacity(0.4),style:StrokeStyle(lineWidth:1,dash:[3,3]))
                            .frame(width:cardWidth,height:cardWidth*1.4).accessibilityLabel("Общая карта ещё не открыта") }
                }
            }
        }.frame(maxWidth:5*cardWidth+24)
            .animation(.timingCurve(0.23,1,0.32,1,duration:reduceMotion ? 0.08 : 0.18),value:cards.count)
    }
}

struct PlayingCardView: View {
    let card: Card
    var size: CGSize = AppTheme.Metrics.boardCard
    var body: some View {
        VStack(spacing:0) {
            Text(card.rankLabel).font(.system(size:max(11,size.width*0.34),weight:.semibold,design:.serif))
            Text(card.symbol).font(.system(size:max(11,size.width*0.38),weight:.medium))
        }.foregroundStyle(card.isRed ? AppTheme.cardRed : AppTheme.cardInk)
            .frame(width:size.width,height:size.height)
            .background(AppTheme.cardFace,in:RoundedRectangle(cornerRadius:7))
            .overlay(RoundedRectangle(cornerRadius:7).stroke(AppTheme.cardInk.opacity(0.1)))
            .accessibilityElement(children:.ignore).accessibilityLabel(card.label)
    }
}

struct SeatView: View {
    let player:PlayerSnapshot
    let isActor:Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(spacing:4) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing:4)) : AnyLayout(HStackLayout(spacing:3))) {
                if player.isButton { Text("D").font(.system(size:11,weight:.bold)).frame(width:18,height:18).background(AppTheme.accent,in:Circle()).foregroundStyle(AppTheme.onAccent).accessibilityLabel("Дилер") }
                Text(player.name).font(.caption.weight(.semibold))
                Text(player.position).font(.caption2).foregroundStyle(AppTheme.muted)
            }
            if !player.folded {
                if typeSize >= .xLarge && !player.cards.isEmpty {
                    CardStrip(cards:player.cards)
                } else {
                HStack(spacing:4) {
                    ForEach(player.cards) { card in PlayingCardView(card:card,size:player.id == 0 ? CGSize(width:42,height:59) : CGSize(width:25,height:35)) }
                    if player.cards.isEmpty {
                        ForEach(0..<2,id:\.self) { _ in
                            RoundedRectangle(cornerRadius:3).fill(AppTheme.surfaceAlt).overlay(RoundedRectangle(cornerRadius:3).stroke(AppTheme.muted.opacity(0.5)))
                                .frame(width:19,height:26).accessibilityLabel("Закрытая карта")
                        }
                    }
                }
                }
            }
            Text("\(player.stack)").font(.subheadline.weight(.semibold).monospacedDigit()).accessibilityLabel("Стек \(player.stack)")
            if player.contribution > 0 { Text("Внёс \(player.contribution)").font(.caption2.monospacedDigit()).foregroundStyle(AppTheme.accent) }
            if player.folded { Text("Пас").font(.caption).foregroundStyle(AppTheme.muted) }
            else if player.allIn { Text("Олл-ин").font(.caption).foregroundStyle(AppTheme.warning) }
            else if isActor { Label(player.id == 0 ? "Ваш ход" : "Ходит",systemImage:"circle.fill").font(.caption2.weight(.semibold)).foregroundStyle(AppTheme.accent) }
            if !player.lastAction.isEmpty && !(isActor && player.lastAction == "Ожидает") && !(player.folded && player.lastAction == "Пас") {
                Text(player.lastAction).font(.caption2).foregroundStyle(AppTheme.muted).fixedSize(horizontal:false,vertical:true)
            }
        }.padding(.vertical,7).padding(.horizontal,5).frame(maxWidth:.infinity)
            .background(isActor ? AppTheme.surfaceAlt : AppTheme.bg.opacity(reduceTransparency ? 1 : 0.78),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(isActor ? AppTheme.accent : .clear,lineWidth:contrast == .increased ? 2.5 : 1.5))
            .accessibilityElement(children:.combine)
    }
}

struct ActionBar: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let snapshot: GameSnapshot
    let botThinking: Bool
    let onAction: (PokerAction) -> Void
    let onBet: (BetEditorKind) -> Void
    var body: some View {
        guard snapshot.actor == 0 else {
            return AnyView(Text(botThinking ? "Бот выбирает ход…" : "Ожидание хода").foregroundStyle(AppTheme.muted).padding())
        }
        let legal = snapshot.legal
        return AnyView(VStack(spacing: AppTheme.Measure.d8) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing:AppTheme.Measure.d8)) : AnyLayout(HStackLayout(spacing:AppTheme.Measure.d8))) {
                if legal.canFold { Button("Пас") { onAction(.fold) }.buttonStyle(SecondaryButtonStyle()) }
                if legal.canCheck { Button("Чек") { onAction(.check) }.buttonStyle(PrimaryButtonStyle()) }
                else { Button("Колл \(legal.callAmount)") { onAction(.call) }.buttonStyle(PrimaryButtonStyle()) }
            }
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing:AppTheme.Measure.d8)) : AnyLayout(HStackLayout(spacing:AppTheme.Measure.d8))) {
                if legal.minRaiseTo != nil { Button(snapshot.currentBet == 0 ? "Ставка…" : "Повысить…") { onBet(.raise) }.buttonStyle(SecondaryButtonStyle()) }
                if legal.canAllIn { Button("Олл-ин") { onBet(.allIn) }.buttonStyle(SecondaryButtonStyle()) }
            }
        })
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
            Group {
            if let error = store.errorMessage {
                Section { ErrorNotice(text: error); Button("Повторить загрузку") { store.reload() } }
            }
            CourseProgressSection()
            if store.attempts.isEmpty && store.comparisons.isEmpty && store.positions.isEmpty && store.evCalls.isEmpty && store.blockers.isEmpty {
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
            Section("Учебный стол") {
                LabeledContent("Блайнды", value: "5 / 10")
                Picker("Учебный профиль ботов", selection: Binding(get: { game.selectedBotLevel }, set: { game.selectBotLevel($0) })) {
                    ForEach(BotLevel.allCases, id: \.self) { level in Text(level.title).tag(level) }
                }.accessibilityIdentifier("settings.botLevel")
                Text(game.selectedBotLevel.learningDescription).font(.footnote)
                Text("Один профиль для всех пяти ботов. Изменение вступает в силу со следующей раздачи.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                Text("Виртуальные фишки и локальные боты. Уроки и прогресс доступны офлайн.").font(.footnote).foregroundStyle(AppTheme.muted)
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
            .foregroundStyle(AppTheme.onAccent)
            .background(configuration.isPressed ? AppTheme.accentPressed : AppTheme.accent,in:RoundedRectangle(cornerRadius:12))
            .opacity(enabled ? 1 : 0.45)
    }
}
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.font(.body.weight(.medium)).multilineTextAlignment(.center)
            .frame(maxWidth:.infinity,minHeight:48).padding(.horizontal,12)
            .foregroundStyle(AppTheme.text)
            .background(configuration.isPressed ? AppTheme.border : AppTheme.surfaceAlt,in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border,lineWidth:1))
            .opacity(enabled ? 1 : 0.45)
    }
}
struct DarkGroupBoxStyle: GroupBoxStyle { func makeBody(configuration: Configuration) -> some View { VStack(alignment: .leading, spacing: AppTheme.Measure.d8) { configuration.label.font(.headline); configuration.content }.padding().background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius)) } }

private extension View {
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
