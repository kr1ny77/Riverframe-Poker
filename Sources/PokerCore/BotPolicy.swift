import Foundation

/// Учебный профиль общего уровня стола. Все пять ботов получают одно значение
/// в начале раздачи.
public enum BotLevel: String, CaseIterable, Codable, Sendable {
    case beginner
    case amateur
    case confident
    case strong
    case challenge

    public var title: String {
        switch self {
        case .beginner: "Новичок"
        case .amateur: "Любитель"
        case .confident: "Уверенный"
        case .strong: "Сильный"
        case .challenge: "Испытание"
        }
    }

    public var learningDescription: String {
        switch self {
        case .beginner: "Учебный профиль с простыми решениями по готовой руке."
        case .amateur: "Учебный профиль, близкий к базовому поведению стола."
        case .confident: "Учебный профиль учитывает позицию, цену колла и дро."
        case .strong: "Учебный профиль учитывает позицию, стеки, цену и число соперников."
        case .challenge: "Учебный профиль использует условную модель диапазонов и несколько размеров ставок."
        }
    }
}

public enum BotStreet: Int, Codable, Sendable {
    case preflop, flop, turn, river
}

/// Публичные сведения об участнике. Карты отсутствуют по контракту.
public struct BotSeatObservation: Equatable, Sendable {
    public let seat: Int
    public let stack: Int64
    public let streetContribution: Int64
    public let totalContribution: Int64
    public let folded: Bool
    public let allIn: Bool
    public let isButton: Bool

    public init(seat: Int, stack: Int64, streetContribution: Int64, totalContribution: Int64, folded: Bool, allIn: Bool, isButton: Bool) {
        self.seat = seat
        self.stack = stack
        self.streetContribution = streetContribution
        self.totalContribution = totalContribution
        self.folded = folded
        self.allIn = allIn
        self.isButton = isButton
    }
}

public enum BotPublicActionKind: Equatable, Sendable {
    case blind(Int64)
    case fold
    case check
    case call(Int64)
    case raiseTo(Int64)
}

/// Хронология открытых действий. Она не содержит закрытых карт и состояния колоды.
public struct BotPublicAction: Equatable, Sendable {
    public let seat: Int
    public let street: BotStreet
    public let kind: BotPublicActionKind

    public init(seat: Int, street: BotStreet, kind: BotPublicActionKind) {
        self.seat = seat
        self.street = street
        self.kind = kind
    }
}

/// Слой банка описывает общедоступную сумму и места, способные за неё бороться.
public struct BotPotLayer: Equatable, Sendable {
    public let amount: Int64
    public let eligibleSeats: [Int]

    public init(amount: Int64, eligibleSeats: [Int]) {
        self.amount = amount
        self.eligibleSeats = eligibleSeats
    }
}

/// Неизменяемый снимок, передаваемый вычислителю. Он содержит две карты
/// принимающего решение бота и только публичные данные раздачи.
public struct BotObservation: Equatable, Sendable {
    public let handNumber: Int
    public let revision: Int
    public let actingSeat: Int
    public let street: BotStreet
    public let ownCards: [Card]
    public let board: [Card]
    public let seats: [BotSeatObservation]
    public let pot: Int64
    public let currentBet: Int64
    public let smallBlind: Int64
    public let bigBlind: Int64
    public let legal: LegalActions
    public let publicActions: [BotPublicAction]
    public let potLayers: [BotPotLayer]

    public init(handNumber: Int, revision: Int, actingSeat: Int, street: BotStreet, ownCards: [Card], board: [Card], seats: [BotSeatObservation], pot: Int64, currentBet: Int64, smallBlind: Int64 = 5, bigBlind: Int64 = 10, legal: LegalActions, publicActions: [BotPublicAction] = [], potLayers: [BotPotLayer] = []) {
        precondition(ownCards.count == 2)
        precondition(Set(ownCards + board).count == ownCards.count + board.count)
        precondition((0...5).contains(board.count))
        precondition(Set(seats.map(\.seat)).count == seats.count)
        precondition(seats.contains { $0.seat == actingSeat })
        self.handNumber = handNumber
        self.revision = revision
        self.actingSeat = actingSeat
        self.street = street
        self.ownCards = ownCards
        self.board = board
        self.seats = seats
        self.pot = pot
        self.currentBet = currentBet
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.legal = legal
        self.publicActions = publicActions
        self.potLayers = potLayers
    }

    public var ownSeat: BotSeatObservation { seats.first { $0.seat == actingSeat }! }
    public var liveOpponents: Int { seats.filter { $0.seat != actingSeat && !$0.folded }.count }
    public var effectiveStack: Int64 {
        let opponents = seats.filter { $0.seat != actingSeat && !$0.folded }.map(\.stack)
        return min(ownSeat.stack, opponents.max() ?? ownSeat.stack)
    }
    public var position: Int {
        guard let button = seats.first(where: \.isButton)?.seat else { return 0 }
        return (actingSeat - button + seats.count) % seats.count
    }
    public var isLatePosition: Bool { position == 0 || position >= max(0, seats.count - 2) }
    public var callPrice: Double {
        guard legal.callAmount > 0 else { return 0 }
        return Double(legal.callAmount) / Double(max(1, availablePot + legal.callAmount))
    }

    /// Банк, за который текущий бот сохраняет право бороться после колла.
    public var availablePot: Int64 {
        guard !potLayers.isEmpty else { return pot }
        return potLayers.reduce(0) { partial, layer in
            partial + (layer.eligibleSeats.contains(actingSeat) ? layer.amount : 0)
        }
    }
}

extension LegalActions: Equatable {
    public static func == (lhs: LegalActions, rhs: LegalActions) -> Bool {
        lhs.canFold == rhs.canFold && lhs.canCheck == rhs.canCheck && lhs.callAmount == rhs.callAmount && lhs.minRaiseTo == rhs.minRaiseTo && lhs.maxRaiseTo == rhs.maxRaiseTo && lhs.canAllIn == rhs.canAllIn
    }
}

/// Чистый вычислитель учебных эвристик. Он работает только со снимком и seed.
public enum BotPolicy {
    public static let version = 1
    public static func sampleCount(for level: BotLevel) -> Int {
        switch level { case .confident: 48; case .strong: 80; case .challenge: 128; default: 0 }
    }
    public static func decide(_ observation: BotObservation, level: BotLevel, seed: UInt64) throws -> PokerAction {
        try Task.checkCancellation()
        if level == .amateur { return amateur(observation, seed: seed) }

        var random = SeededGenerator(state: seed)
        let roll = Int(random.next() % 100)
        let evaluation = try evaluate(observation, level: level, random: &random)
        if level == .challenge, observation.street != .preflop {
            return conditionalDecision(observation, equity: evaluation.equity, hasDraw: evaluation.hasDraw, roll: roll)
        }
        try Task.checkCancellation()

        if observation.legal.canCheck {
            if shouldRaise(evaluation: evaluation, observation: observation, level: level, roll: roll), let target = raiseTarget(observation, level: level, evaluation: evaluation) {
                return .raiseTo(target)
            }
            return .check
        }

        if shouldRaise(evaluation: evaluation, observation: observation, level: level, roll: roll), let target = raiseTarget(observation, level: level, evaluation: evaluation) {
            return .raiseTo(target)
        }

        let threshold: Double
        switch level {
        case .beginner: threshold = 0.62
        case .confident: threshold = evaluation.hasDraw ? 0.36 : 0.46
        case .strong: threshold = evaluation.hasDraw ? 0.40 : 0.50
        case .challenge: threshold = evaluation.hasDraw ? 0.42 : 0.54
        case .amateur: threshold = 0
        }
        let stackPenalty = level != .beginner && observation.effectiveStack <= observation.bigBlind * 20 ? 0.04 : 0
        let multiwayPenalty = level == .beginner ? 0 : Double(max(0, observation.liveOpponents - 1)) * 0.05
        let equity = evaluation.equity - stackPenalty - multiwayPenalty
        if equity >= observation.callPrice + threshold - 0.28 { return .call }
        if level == .beginner && (evaluation.madeCategory >= 1 || roll < 30) { return .call }
        return observation.legal.canFold ? .fold : .call
    }

    /// Basic-v1 rule preserved for the default profile. `seed` supplies the
    /// first historical decision roll, so a repeated observation repeats exactly.
    static func amateur(_ observation: BotObservation, seed: UInt64) -> PokerAction {
        var random = SeededGenerator(state: seed)
        let roll = Int(random.next() % 100)
        let pair = observation.ownCards[0].rank == observation.ownCards[1].rank
        let high = max(observation.ownCards[0].rank, observation.ownCards[1].rank)
        let strength = observation.board.count >= 3 ? HandEvaluator.best(of: observation.ownCards + observation.board).category : (pair ? 2 : (high >= 12 ? 1 : 0))
        if strength >= 2, roll < 22, let minimum = observation.legal.minRaiseTo {
            let target = max(minimum, observation.currentBet + max(10, observation.pot / 2))
            if target <= observation.legal.maxRaiseTo { return .raiseTo(target) }
        }
        if observation.legal.canCheck { return .check }
        if strength >= 1 || observation.legal.callAmount <= max(10, observation.ownSeat.stack / 12) || roll < 18 { return .call }
        return .fold
    }

    private struct Evaluation: Sendable {
        let madeCategory: Int
        let hasDraw: Bool
        let equity: Double
    }

    private static func evaluate(_ observation: BotObservation, level: BotLevel, random: inout SeededGenerator) throws -> Evaluation {
        let made: Int
        if observation.board.count >= 3 { made = HandEvaluator.best(of: observation.ownCards + observation.board).category }
        else if level == .beginner {
            made = observation.ownCards[0].rank == observation.ownCards[1].rank ? 2 : (observation.ownCards.map(\.rank).max()! >= 12 ? 1 : 0)
        } else { made = preflopStrength(observation) }
        let draw = level != .beginner && made <= 1 ? drawStrength(observation) : 0
        guard observation.board.count >= 3, level == .strong || level == .challenge || level == .confident else {
            return Evaluation(madeCategory: made, hasDraw: draw > 0, equity: heuristicEquity(made: made, draw: draw, observation: observation))
        }
        let samples = sampleCount(for: level)
        let monteCarlo = try conditionalEquity(observation, level: level, samples: samples, random: &random)
        return Evaluation(madeCategory: made, hasDraw: draw > 0, equity: monteCarlo)
    }

    /// Version 1 of the 169-class preflop table. Every rank pair maps to a
    /// deterministic opening weight; suited and offsuit classes form separate
    /// entries. The profile and position then set the required weight.
    private static func preflopWeight(_ o: BotObservation) -> Int {
        let high = max(o.ownCards[0].rank, o.ownCards[1].rank)
        let low = min(o.ownCards[0].rank, o.ownCards[1].rank)
        let pair = high == low
        let suited = o.ownCards[0].suit == o.ownCards[1].suit
        let gap = high - low
        var weight = pair ? 68 + (high - 2) * 2 : (high - 2) * 4 + (low - 2) * 2
        if suited { weight += 10 }
        if gap <= 1 { weight += 7 }
        if high >= 13 && low >= 10 { weight += 12 }
        return min(100, max(0, weight))
    }

    private static func preflopStrength(_ o: BotObservation) -> Int {
        let weight = preflopWeight(o)
        let raises = o.publicActions.filter { if case .raiseTo = $0.kind { true } else { false } }.count
        let threshold = [42, 56, 50, 58, 54, 46][o.position] + min(3, raises) * 8
        if weight >= threshold + 16 { return 2 }
        if weight >= threshold { return 1 }
        return 0
    }

    private static func drawStrength(_ o: BotObservation) -> Int {
        guard o.board.count == 3 || o.board.count == 4 else { return 0 }
        let cards = o.ownCards + o.board
        let ranks = Set(cards.map(\.rank))
        var missing = Set<Int>()
        for high in 5...14 {
            let sequence = high == 5 ? Set([14, 2, 3, 4, 5]) : Set((high - 4)...high)
            if sequence.isSubset(of: ranks) { return 0 }
            let remainder = sequence.subtracting(ranks)
            if remainder.count == 1 { missing.formUnion(remainder) }
        }
        let suits = Dictionary(grouping: cards, by: \.suit)
        let flushSuit = suits.first { $0.value.count == 4 }?.key
        let known = Set(cards)
        let outs = (0..<52).map(Card.init(id:)).filter {
            !known.contains($0) && (missing.contains($0.rank) || $0.suit == flushSuit)
        }.count
        return outs >= 8 ? 2 : (outs > 0 ? 1 : 0)
    }

    private static func heuristicEquity(made: Int, draw: Int, observation: BotObservation) -> Double {
        let base = [0.18, 0.48, 0.63, 0.72, 0.79, 0.84, 0.92, 0.97, 0.99][min(8, max(0, made))]
        let drawBonus = draw == 2 ? (observation.board.count == 3 ? 0.20 : 0.10) : (draw == 1 ? 0.05 : 0)
        return min(0.99, base + drawBonus)
    }

    /// Оценка Монте-Карло против условных взвешенных диапазонов неизвестных рук.
    /// Известные карты исключены; будущая доска выбирается из оставшихся карт.
    /// Фиксированы версия модели, seed и число выборок; это учебная оценка.
    private static func conditionalEquity(_ o: BotObservation, level: BotLevel, samples: Int, random: inout SeededGenerator) throws -> Double {
        let known = Set(o.ownCards + o.board)
        let opponentSeats = o.seats.filter { $0.seat != o.actingSeat && !$0.folded }
        var score = 0.0
        for sample in 0..<samples {
            if sample & 15 == 0 { try Task.checkCancellation() }
            var available = (0..<52).map(Card.init(id:)).filter { !known.contains($0) }
            func take() -> Card {
                let index = Int(random.next() % UInt64(available.count))
                return available.remove(at: index)
            }
            var hands: [[Card]] = []
            let aggression = o.publicActions.reduce(into: 0) { count, action in
                if case .raiseTo = action.kind { count += 1 }
            }
            for opponent in opponentSeats {
                // Six candidate combinations form a bounded conditional range.
                // The weighted pick favours publicly plausible aggressive hands.
                var candidates: [([Card], Int)] = []
                for _ in 0..<6 {
                    let a = Int(random.next() % UInt64(available.count))
                    var b = Int(random.next() % UInt64(available.count - 1))
                    if b >= a { b += 1 }
                    let first = available[a], second = available[b]
                    let high = max(first.rank, second.rank)
                    let connected = abs(first.rank - second.rank) <= 2
                    let boardBlocker = o.board.contains { $0.rank == first.rank || $0.rank == second.rank }
                    let baseline = level == .challenge ? 14 : 24
                    let seatRaises = o.publicActions.filter { action in
                        guard action.seat == opponent.seat else { return false }
                        if case .raiseTo = action.kind { return true }; return false
                    }.count
                    let premium = (high >= 11 ? 28 : 0) + (first.rank == second.rank ? 24 : 0)
                    let pressure = level == .confident ? 0 : min(4, aggression + seatRaises)
                    let weight = baseline + premium * (1 + pressure) + (first.suit == second.suit ? 9 : 0) + (connected ? 5 : 0) - (boardBlocker ? 4 : 0)
                    candidates.append(([first, second], weight))
                }
                let total = candidates.reduce(0) { $0 + $1.1 }
                var pick = Int(random.next() % UInt64(total))
                let choice = candidates.first { candidate in
                    pick -= candidate.1
                    return pick < 0
                }!.0
                hands.append(choice)
                available.removeAll { $0 == choice[0] || $0 == choice[1] }
            }
            var board = o.board
            while board.count < 5 { board.append(take()) }
            let hero = HandEvaluator.best(of: o.ownCards + board)
            let ranks = hands.map { HandEvaluator.best(of: $0 + board) }
            func share(against indices: [Int]) -> Double {
                let competing = indices.map { ranks[$0] }
                guard let top = competing.max() else { return 1 }
                if hero > top { return 1 }
                if hero == top { return 1 / Double(competing.filter { $0 == hero }.count + 1) }
                return 0
            }
            // Weight equity by the pots AFTER this call: the added chips may
            // belong only to a side pot with fewer eligible opponents.
            let projected = o.seats.map { seat in
                seat.totalContribution + (seat.seat == o.actingSeat ? o.legal.callAmount : 0)
            }
            let cap = o.ownSeat.totalContribution + o.legal.callAmount
            let levels = Set(projected.filter { $0 > 0 }).sorted()
            var previous: Int64 = 0
            let layers: [BotPotLayer] = levels.compactMap { level in
                defer { previous = level }
                guard level <= cap else { return nil }
                let members = o.seats.indices.filter { projected[$0] >= level }
                return BotPotLayer(amount: (level - previous) * Int64(members.count),
                    eligibleSeats: members.filter { !o.seats[$0].folded }.map { o.seats[$0].seat })
            }
            if layers.isEmpty { score += share(against: Array(ranks.indices)) }
            else {
                let total = Double(layers.reduce(Int64(0)) { $0 + $1.amount })
                for layer in layers {
                    let indices = opponentSeats.indices.filter { layer.eligibleSeats.contains(opponentSeats[$0].seat) }
                    score += Double(layer.amount) / total * share(against: indices)
                }
            }
        }
        return score / Double(samples)
    }

    /// One-step conditional model: all players with chips either fold together
    /// or match the candidate up to their stacks; existing all-ins always contest.
    /// Future betting is omitted. Values are model estimates in virtual chips.
    static func conditionalDecision(_ o: BotObservation, equity eq: Double, hasDraw: Bool, roll: Int) -> PokerAction {
        let call = Double(o.legal.callAmount)
        var best = o.legal.canCheck ? PokerAction.check : (o.legal.canFold ? .fold : .call)
        var value = o.legal.canCheck ? eq * Double(o.availablePot) : 0
        let callValue = eq * Double(o.availablePot) - (1 - eq) * call
        if !o.legal.canCheck && callValue > value { value = callValue; best = .call }
        guard let minimum = o.legal.minRaiseTo else { return best }
        let opponents = o.seats.filter { $0.seat != o.actingSeat && !$0.folded }
        let foldChance = opponents.contains(where: \.allIn) ? 0 : conditionalFoldChance(o)
        let fractions = o.liveOpponents == 1 && o.effectiveStack > o.bigBlind * 60
            ? [0.25, 0.5, 0.75, 1.0, 1.25] : [0.25, 0.5, 0.75, 1.0]
        for fraction in fractions {
            let proposed = o.currentBet + Int64((Double(max(o.bigBlind, o.pot + o.legal.callAmount)) * fraction).rounded())
            let target = min(o.legal.maxRaiseTo, max(minimum, proposed))
            guard target >= minimum else { continue }
            let paid = Double(target - o.ownSeat.streetContribution)
            let replies = opponents.reduce(Int64(0)) { total, seat in
                total + min(seat.stack, max(0, target - seat.streetContribution))
            }
            let raiseValue = foldChance * Double(o.availablePot)
                + (1 - foldChance) * (eq * (Double(o.availablePot + replies)) - (1 - eq) * paid)
            // A deterministic mixed gate limits low-equity semi-bluffs.
            if raiseValue > value && (eq >= 0.48 || (hasDraw && roll < 38)) {
                value = raiseValue
                best = .raiseTo(target)
            }
        }
        return best
    }

    private static func shouldRaise(evaluation: Evaluation, observation: BotObservation, level: BotLevel, roll: Int) -> Bool {
        if observation.street == .preflop && observation.currentBet <= observation.bigBlind {
            let weight = preflopWeight(observation)
            switch level {
            case .beginner: return evaluation.madeCategory >= 2
            case .confident: return weight >= [38, 54, 48, 56, 50, 42][observation.position]
            case .strong: return weight >= [34, 50, 44, 52, 46, 38][observation.position]
            case .challenge: return weight >= [30, 46, 40, 48, 42, 34][observation.position]
            case .amateur: return false
            }
        }
        switch level {
        case .beginner: return evaluation.madeCategory >= 2 && roll < 12
        case .confident: return evaluation.equity >= 0.67 || (evaluation.hasDraw && observation.isLatePosition && roll < 18)
        case .strong: return evaluation.equity >= 0.63 || (evaluation.hasDraw && observation.liveOpponents == 1 && roll < 28)
        case .challenge: return evaluation.equity >= 0.59
        case .amateur: return false
        }
    }

    private static func raiseTarget(_ o: BotObservation, level: BotLevel, evaluation: Evaluation) -> Int64? {
        guard let minimum = o.legal.minRaiseTo else { return nil }
        let pot = max(o.bigBlind, o.pot)
        let fraction: Double
        switch level {
        case .beginner: fraction = 0
        case .confident: fraction = o.currentBet <= o.bigBlind ? 2.5 : (evaluation.hasDraw ? 0.33 : 0.66)
        case .strong: fraction = evaluation.hasDraw ? 0.66 : (o.liveOpponents > 1 ? 1.0 : (evaluation.equity > 0.78 ? 0.66 : 0.33))
        case .challenge:
            if o.liveOpponents == 1 && o.effectiveStack > o.bigBlind * 60 { fraction = 1.25 }
            else if evaluation.equity > 0.82 { fraction = 1.0 }
            else if evaluation.hasDraw { fraction = 0.75 }
            else if evaluation.equity < 0.62 { fraction = 0.25 }
            else { fraction = 0.5 }
        case .amateur: fraction = 0.5
        }
        let proposed: Int64
        if level == .beginner { proposed = minimum }
        else if level == .confident && o.street == .preflop && o.currentBet <= o.bigBlind { proposed = o.bigBlind * 5 / 2 }
        else { proposed = o.currentBet + Int64((Double(pot) * fraction).rounded()) }
        let target = max(minimum, proposed)
        return target <= o.legal.maxRaiseTo ? target : nil
    }

    /// Условная модель fold equity: учитывает публичную агрессию, число
    /// соперников и блокеры крупных рангов. Это эвристическая оценка, а не
    /// предсказание стратегии соперника.
    private static func conditionalFoldChance(_ o: BotObservation) -> Double {
        let raises = o.publicActions.reduce(into: 0) { total, action in
            if case .raiseTo = action.kind { total += 1 }
        }
        let blockers = o.ownCards.filter { $0.rank >= 12 }.count
        let headsUp = o.liveOpponents == 1 ? 0.16 : -0.08 * Double(o.liveOpponents - 1)
        return min(0.62, max(0.08, 0.30 + headsUp - Double(raises) * 0.06 + Double(blockers) * 0.035))
    }
}
