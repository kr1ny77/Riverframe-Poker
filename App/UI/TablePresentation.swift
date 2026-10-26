import SwiftUI
import PokerCore

private enum TableTokens {
    static let sceneRadius: CGFloat = 24
    static let seatRadius: CGFloat = 12
    static let heroRadius: CGFloat = 16
    static let compactGap: CGFloat = 8
    static let sceneGap: CGFloat = 14
    static let actionDockGap: CGFloat = 10
    static let cardCorner: CGFloat = 9
}

struct TableView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var game: GameViewModel
    @State private var editor: BetEditorKind?

    var body: some View {
        let snapshot = game.snapshot

        ScrollView {
            VStack(spacing: AppTheme.Measure.d12) {
                tableHeader(snapshot)
                if typeSize.isAccessibilitySize { sessionControls(snapshot) }
                PokerTableView(snapshot: snapshot)

                if snapshot.complete {
                    OutcomeView(snapshot: snapshot) { game.startFreshHand() }
                }
                if let error = game.errorMessage { ErrorNotice(text: error) }
            }
            .padding()
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

    private func tableHeader(_ snapshot: GameSnapshot) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Measure.d12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Раздача \(snapshot.handNumber)")
                    .font(.headline)
                Text("Учебный профиль: \(game.activeBotLevel.title)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityIdentifier("table.botProfile")
                Text(turnDescription(snapshot))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: AppTheme.Measure.d8)
            Button(game.isPaused ? "Продолжить" : "Пауза") {
                game.setPaused(!game.isPaused)
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(AppTheme.surfaceAlt, in: Capsule())
        }
        .accessibilityElement(children: .contain)
    }

    private func turnDescription(_ snapshot: GameSnapshot) -> String {
        guard let actor = snapshot.players.first(where: { $0.id == snapshot.actor }) else {
            return snapshot.street
        }
        return "\(snapshot.street) · \(actor.id == 0 ? "Ваш ход" : actor.name)"
    }

    @ViewBuilder
    private func sessionControls(_ snapshot: GameSnapshot) -> some View {
        if !snapshot.complete {
            VStack(spacing: TableTokens.actionDockGap) {
                if game.isPaused {
                    Text("Раздача на паузе. Нажмите «Продолжить».")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                    Button("Продолжить") { game.setPaused(false) }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    ActionBar(
                        snapshot: snapshot,
                        botThinking: game.isBotThinking,
                        onAction: game.send,
                        onBet: { editor = $0 }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(AppTheme.bg)
            .accessibilityElement(children: .contain)
        }
    }
}

struct PokerTableView: View {
    let snapshot: GameSnapshot
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var opponents: [PlayerSnapshot] {
        snapshot.players.filter { $0.id != 0 }
    }

    private var hero: PlayerSnapshot? {
        snapshot.players.first { $0.id == 0 }
    }

    private var usesSequentialLayout: Bool {
        typeSize.isAccessibilitySize || verticalSizeClass == .compact
    }

    var body: some View {
        Group {
            if usesSequentialLayout {
                sequentialScene
            } else {
                ViewThatFits(in: .horizontal) {
                    standardScene.frame(minWidth: 330)
                    sequentialScene
                }
            }
        }
        .padding(TableTokens.sceneGap)
        .frame(maxWidth: .infinity)
        .foregroundStyle(AppTheme.tableText)
        .background(AppTheme.table, in: RoundedRectangle(cornerRadius: TableTokens.sceneRadius))
        .overlay {
            RoundedRectangle(cornerRadius: TableTokens.sceneRadius)
                .stroke(AppTheme.tableAccent.opacity(0.65), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Покерный стол. \(snapshot.street). Банк \(snapshot.pot). Текущая ставка \(snapshot.currentBet).")
    }

    private var standardScene: some View {
        VStack(spacing: TableTokens.sceneGap) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: TableTokens.compactGap), count: 3),
                spacing: TableTokens.compactGap
            ) {
                ForEach(Array(opponents.prefix(3))) { player in
                    SeatView(player: player, isActor: player.id == snapshot.actor)
                }
            }

            TableBoard(snapshot: snapshot)
                .frame(maxWidth: .infinity)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: TableTokens.compactGap), count: 2),
                spacing: TableTokens.compactGap
            ) {
                ForEach(Array(opponents.dropFirst(3))) { player in
                    SeatView(player: player, isActor: player.id == snapshot.actor)
                }
            }

            if let hero {
                HeroStrip(player: hero, snapshot: snapshot, isActor: hero.id == snapshot.actor)
            }
        }
    }

    private var sequentialScene: some View {
        VStack(spacing: TableTokens.sceneGap) {
            TableBoard(snapshot: snapshot)
            if let hero {
                HeroStrip(player: hero, snapshot: snapshot, isActor: hero.id == snapshot.actor)
            }
            DisclosureGroup("Соперники (\(opponents.count))") {
                VStack(spacing: TableTokens.compactGap) {
                    ForEach(opponents) { player in
                        SeatView(player: player, isActor: player.id == snapshot.actor)
                    }
                }
                .padding(.top, TableTokens.compactGap)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.tableText)
        }
    }
}

private struct TableBoard: View {
    let snapshot: GameSnapshot

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("БАНК")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.tableMuted)
                Text("\(snapshot.pot)")
                    .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                Text("Ставка \(snapshot.currentBet)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.tableMuted)
            }
            .accessibilityElement(children: .combine)

            BoardView(cards: snapshot.board)
        }
        .padding(12)
        .background(AppTheme.tableSurface, in: RoundedRectangle(cornerRadius: TableTokens.seatRadius))
    }
}

struct BoardView: View {
    let cards: [Card]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 46

    private var cardWidth: CGFloat { min(width, 58) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { cardSlots }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cardWidth), spacing: 6), count: 3), spacing: 6) {
                cardSlots
            }
        }
        .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.16), value: cards.count)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Общие карты")
    }

    @ViewBuilder
    private var cardSlots: some View {
        ForEach(0..<5, id: \.self) { index in
            if index < cards.count {
                PlayingCardView(card: cards[index], size: CGSize(width: cardWidth, height: cardWidth * 1.4))
                    .transition(reduceMotion ? .identity : .opacity)
            } else {
                RoundedRectangle(cornerRadius: TableTokens.cardCorner)
                    .stroke(AppTheme.tableMuted.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: cardWidth, height: cardWidth * 1.4)
                    .accessibilityLabel("Общая карта ещё не открыта")
            }
        }
    }
}

struct PlayingCardView: View {
    let card: Card
    var size: CGSize = AppTheme.Metrics.boardCard

    var body: some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(card.rankLabel)
                .font(.system(size: max(12, size.width * 0.42), weight: .bold, design: .rounded))
            Text(card.symbol)
                .font(.system(size: max(12, size.width * 0.30), weight: .semibold))
            if size.width >= 36 {
                Spacer(minLength: 0)
                Text(card.symbol)
                    .font(.system(size: max(9, size.width * 0.2), weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .foregroundStyle(card.isRed ? AppTheme.cardRed : AppTheme.cardInk)
        .padding(max(4, size.width * 0.09))
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(AppTheme.cardFace, in: RoundedRectangle(cornerRadius: TableTokens.cardCorner))
        .overlay {
            RoundedRectangle(cornerRadius: TableTokens.cardCorner)
                .stroke(AppTheme.cardInk.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.label)
    }
}

struct SeatView: View {
    let player: PlayerSnapshot
    let isActor: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if player.isButton {
                    Text("D")
                        .font(.caption2.weight(.bold))
                        .frame(width: 18, height: 18)
                        .background(AppTheme.tableAccent, in: Circle())
                        .foregroundStyle(AppTheme.cardInk)
                        .accessibilityLabel("Дилер")
                }
                Text(player.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(player.stack)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .accessibilityLabel("Стек \(player.stack)")
            }
            Text("\(player.position) · \(status)")
                .font(.caption2)
                .foregroundStyle(AppTheme.tableMuted)
                .lineLimit(2)
            if player.contribution > 0 {
                Text("Внёс \(player.contribution)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.tableAccent)
            }
            if !player.cards.isEmpty {
                HStack(spacing: 4) {
                    ForEach(player.cards) { card in
                        PlayingCardView(card: card, size: CGSize(width: 32, height: 45))
                    }
                }
                .accessibilityLabel("Открытые карты")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(seatBackground, in: RoundedRectangle(cornerRadius: TableTokens.seatRadius))
        .overlay {
            RoundedRectangle(cornerRadius: TableTokens.seatRadius)
                .stroke(isActor ? AppTheme.tableAccent : AppTheme.tableMuted.opacity(0.42), lineWidth: isActor && contrast == .increased ? 2.5 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var status: String {
        if player.folded { return "пас" }
        if player.allIn { return "олл-ин" }
        if isActor { return player.id == 0 ? "ваш ход" : "ходит" }
        if player.contribution > 0 { return "внёс \(player.contribution)" }
        return player.lastAction.isEmpty ? "ожидает" : player.lastAction
    }

    private var seatBackground: Color {
        reduceTransparency ? AppTheme.tableSurface : AppTheme.tableSurface.opacity(0.92)
    }

    private var accessibilityDescription: String {
        let contribution = player.contribution > 0 ? ", внёс \(player.contribution)" : ""
        let lastAction = player.lastAction.isEmpty ? "" : ", последнее действие \(player.lastAction)"
        return "\(player.name), \(player.position), стек \(player.stack), \(status)\(contribution)\(lastAction)"
    }
}

private struct HeroStrip: View {
    let player: PlayerSnapshot
    let snapshot: GameSnapshot
    let isActor: Bool
    @ScaledMetric(relativeTo: .body) private var cardWidth: CGFloat = 54

    private var displayedCardWidth: CGFloat { min(cardWidth, 70) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) { horizontalContent }
            VStack(alignment: .leading, spacing: 10) { verticalContent }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.tableSurface, in: RoundedRectangle(cornerRadius: TableTokens.heroRadius))
        .overlay {
            RoundedRectangle(cornerRadius: TableTokens.heroRadius)
                .stroke(isActor ? AppTheme.tableAccent : AppTheme.tableMuted.opacity(0.45), lineWidth: 1.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    @ViewBuilder
    private var horizontalContent: some View {
        cardContent
        heroSummary
        Spacer(minLength: 4)
        decisionPrice
    }

    @ViewBuilder
    private var verticalContent: some View {
        HStack(spacing: 12) {
            cardContent
            heroSummary
        }
        decisionPrice
    }

    @ViewBuilder
    private var cardContent: some View {
        HStack(spacing: 6) {
            if player.cards.isEmpty {
                HiddenCardPair(size: CGSize(width: displayedCardWidth, height: displayedCardWidth * 1.4))
            } else {
                ForEach(player.cards) { card in
                    PlayingCardView(card: card, size: CGSize(width: displayedCardWidth, height: displayedCardWidth * 1.4))
                }
            }
        }
    }

    private var heroSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Вы")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.tableMuted)
            Text("\(player.position) · стек \(player.stack)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
            if player.contribution > 0 {
                Text("Внесено \(player.contribution)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tableMuted)
            }
        }
    }

    @ViewBuilder
    private var decisionPrice: some View {
        if isActor {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.legal.canCheck ? "Цена решения" : "Колл")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.tableMuted)
                Text(snapshot.legal.canCheck ? "0 · можно чек" : "\(snapshot.legal.callAmount)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }
        }
    }

    private var heroAccessibilityLabel: String {
        let price = isActor ? (snapshot.legal.canCheck ? "можно чек" : "колл \(snapshot.legal.callAmount)") : "ожидание хода"
        return "Ваши карты, позиция \(player.position), стек \(player.stack), \(price)"
    }
}

private struct HiddenCardPair: View {
    let size: CGSize

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: TableTokens.cardCorner)
                    .fill(AppTheme.tableMuted.opacity(0.34))
                    .overlay {
                        RoundedRectangle(cornerRadius: TableTokens.cardCorner)
                            .stroke(AppTheme.tableText.opacity(0.45), lineWidth: 1)
                    }
                    .frame(width: size.width, height: size.height)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Две закрытые карты")
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
            return AnyView(
                Label(botThinking ? "Бот выбирает ход…" : "Ожидание хода", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            )
        }

        let legal = snapshot.legal
        return AnyView(
            VStack(spacing: TableTokens.actionDockGap) {
                actionRow {
                    if legal.canFold {
                        Button("Пас") { onAction(.fold) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    if legal.canCheck {
                        Button("Чек") { onAction(.check) }
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button("Колл \(legal.callAmount)") { onAction(.call) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                if legal.minRaiseTo != nil || legal.canAllIn {
                    actionRow {
                        if legal.minRaiseTo != nil {
                            Button(snapshot.currentBet == 0 ? "Ставка…" : "Повысить…") { onBet(.raise) }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                        if legal.canAllIn {
                            Button("Олл-ин") { onBet(.allIn) }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Действия в раздаче")
        )
    }

    @ViewBuilder
    private func actionRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: TableTokens.actionDockGap, content: content)
        } else {
            HStack(spacing: TableTokens.actionDockGap, content: content)
        }
    }
}
