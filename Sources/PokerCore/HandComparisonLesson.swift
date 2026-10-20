import Foundation

public enum HandComparisonMode: String, Codable, Sendable, CaseIterable {
    case winner
    case bestFive

    public var title: String {
        switch self {
        case .winner: "Выберите победителя"
        case .bestFive: "Выберите лучшие пять карт"
        }
    }
}

public enum ShowdownWinner: String, Codable, CaseIterable, Sendable {
    case first
    case second
    case split

    public var title: String {
        switch self {
        case .first: "Игрок A"
        case .second: "Игрок B"
        case .split: "Ничья"
        }
    }
}

public enum HandComparisonAnswer: Codable, Equatable, Sendable {
    case winner(ShowdownWinner)
    case bestFive([Card])

    private enum CodingKeys: String, CodingKey { case kind, winner, cards }
    private enum Kind: String, Codable { case winner, bestFive }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .winner:
            self = .winner(try container.decode(ShowdownWinner.self, forKey: .winner))
        case .bestFive:
            let ids = try container.decode([Int].self, forKey: .cards)
            guard ids.allSatisfy({ (0..<52).contains($0) }) else {
                throw DecodingError.dataCorruptedError(forKey: .cards, in: container, debugDescription: "Card ID is outside the standard deck")
            }
            self = .bestFive(ids.map(Card.init(id:)))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .winner(let winner):
            try container.encode(Kind.winner, forKey: .kind)
            try container.encode(winner, forKey: .winner)
        case .bestFive(let cards):
            try container.encode(Kind.bestFive, forKey: .kind)
            try container.encode(cards.map(\.id), forKey: .cards)
        }
    }
}

public struct HandComparisonQuestion: Identifiable, Codable, Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case invalidID
        case wrongCardCount
        case invalidCardID
        case duplicateCard
        case nonUniqueBestFive
    }

    public let id: String
    public let first: [Card]
    public let second: [Card]
    public let board: [Card]
    public let mode: HandComparisonMode

    public var firstRank: HandRank { HandEvaluator.best(of: first + board) }
    public var secondRank: HandRank { HandEvaluator.best(of: second + board) }
    public var bestFive: [Card] { firstRank.bestFive }
    public var winner: ShowdownWinner {
        if firstRank > secondRank { return .first }
        if secondRank > firstRank { return .second }
        return .split
    }

    public init(id: String, first: [Card], second: [Card], board: [Card], mode: HandComparisonMode) throws {
        try Self.validate(id: id, first: first, second: second, board: board, mode: mode)
        self.id = id
        self.first = first
        self.second = second
        self.board = board
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey { case id, first, second, board, mode }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let firstIDs = try container.decode([Int].self, forKey: .first)
        let secondIDs = try container.decode([Int].self, forKey: .second)
        let boardIDs = try container.decode([Int].self, forKey: .board)
        let mode = try container.decode(HandComparisonMode.self, forKey: .mode)
        guard (firstIDs + secondIDs + boardIDs).allSatisfy({ (0..<52).contains($0) }) else {
            throw DecodingError.dataCorruptedError(forKey: .first, in: container, debugDescription: "Card ID is outside the standard deck")
        }
        do {
            try self.init(id: id, first: firstIDs.map(Card.init(id:)), second: secondIDs.map(Card.init(id:)), board: boardIDs.map(Card.init(id:)), mode: mode)
        } catch {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid hand-comparison question: \(error)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(first.map(\.id), forKey: .first)
        try container.encode(second.map(\.id), forKey: .second)
        try container.encode(board.map(\.id), forKey: .board)
        try container.encode(mode, forKey: .mode)
    }

    public func isCorrect(_ answer: HandComparisonAnswer) -> Bool {
        switch (mode, answer) {
        case (.winner, .winner(let selected)):
            return selected == winner
        case (.bestFive, .bestFive(let selected)):
            guard selected.count == 5, Set(selected).count == 5,
                  Set(selected).isSubset(of: Set(first + board)) else { return false }
            return HandEvaluator.best(of: selected) == firstRank
        default:
            return false
        }
    }

    public var explanation: [String] {
        let firstText = Self.rankDescription(firstRank)
        let secondText = Self.rankDescription(secondRank)
        var lines = [
            "Игрок A: \(firstRank.title). \(firstText)\(Self.setNote(holeCards: first, rank: firstRank))",
            "Игрок B: \(secondRank.title). \(secondText)\(Self.setNote(holeCards: second, rank: secondRank))"
        ]
        switch winner {
        case .first:
            lines.append("Побеждает игрок A: \(Self.comparisonReason(winner: firstRank, loser: secondRank)).")
        case .second:
            lines.append("Побеждает игрок B: \(Self.comparisonReason(winner: secondRank, loser: firstRank)).")
        case .split:
            lines.append("Ничья: обе лучшие пятёрки имеют одинаковую категорию и одинаковые сравниваемые ранги.")
            if HandEvaluator.best(of: board) == firstRank {
                lines.append("Вся лучшая пятёрка лежит на доске. Шестая карта, масть закрытых карт и более слабые карты руки не дают преимущества.")
            }
        }
        if mode == .bestFive {
            lines.append("Лучшая пятёрка игрока A: \(bestFive.map(\.rankLabel).joined(separator: " ")). Карты руки используют от нуля до двух закрытых карт; важны только сильнейшие пять из семи.")
        }
        return lines
    }

    /// Adds feedback for a submitted answer while keeping the result derived from the evaluator.
    public func explanation(for answer: HandComparisonAnswer) -> [String] {
        var lines = explanation
        guard mode == .bestFive else { return lines }
        guard case .bestFive(let selected) = answer else {
            lines.append("Для этого задания нужно выбрать ровно пять карт игрока A и доски.")
            return lines
        }
        guard selected.count == 5, Set(selected).count == 5,
              Set(selected).isSubset(of: Set(first + board)) else {
            lines.append("Выбранные карты должны быть пятью разными картами игрока A или доски.")
            return lines
        }
        let selectedRank = HandEvaluator.best(of: selected)
        if selectedRank == firstRank {
            lines.append("Выбрана сильнейшая комбинация: \(selectedRank.title). \(Self.rankDescription(selectedRank))")
        } else {
            lines.append("Выбранная пятёрка даёт \(selectedRank.title). \(Self.rankDescription(selectedRank))")
            lines.append("Она слабее лучшей пятёрки игрока A: \(Self.comparisonReason(winner: firstRank, loser: selectedRank)).")
        }
        return lines
    }

    private static func validate(id: String, first: [Card], second: [Card], board: [Card], mode: HandComparisonMode) throws {
        guard first.count == 2, second.count == 2, board.count == 5 else { throw ValidationError.wrongCardCount }
        let all = first + second + board
        guard all.allSatisfy({ (0..<52).contains($0.id) }) else { throw ValidationError.invalidCardID }
        guard Set(all).count == 9 else { throw ValidationError.duplicateCard }
        guard isValidID(id, first: first, second: second, board: board, mode: mode) else { throw ValidationError.invalidID }
        if mode == .bestFive, countBestFiveSubsets(in: first + board) != 1 { throw ValidationError.nonUniqueBestFive }
    }

    private static func isValidID(_ id: String, first: [Card], second: [Card], board: [Card], mode: HandComparisonMode) -> Bool {
        let pieces = id.split(separator: "-", omittingEmptySubsequences: false)
        guard pieces.count == 5, pieces[0] == "hcmp", pieces[1] == "v1",
              HandComparisonLesson.templateKeys.contains(String(pieces[2])),
              pieces[3] == Substring(mode.rawValue) else { return false }
        let fingerprint = (first + second + board).map { String($0.id) }.joined(separator: ".")
        return pieces[4] == Substring(fingerprint)
    }

    private static func countBestFiveSubsets(in cards: [Card]) -> Int {
        let target = HandEvaluator.best(of: cards)
        var count = 0
        for a in 0..<(cards.count - 4) {
            for b in (a + 1)..<(cards.count - 3) {
                for c in (b + 1)..<(cards.count - 2) {
                    for d in (c + 1)..<(cards.count - 1) {
                        for e in (d + 1)..<cards.count where HandEvaluator.best(of: [cards[a], cards[b], cards[c], cards[d], cards[e]]) == target {
                            count += 1
                        }
                    }
                }
            }
        }
        return count
    }

    private static func rankDescription(_ rank: HandRank) -> String {
        let labels = rank.kickers.map(rankLabel).joined(separator: ", ")
        switch rank.category {
        case 0: return "Сравниваются все пять старших карт: \(labels)."
        case 1: return "Пара \(rankLabel(rank.kickers[0])); затем кикеры: \(rank.kickers.dropFirst().map(rankLabel).joined(separator: ", "))."
        case 2: return "Две пары: \(rankLabel(rank.kickers[0])) и \(rankLabel(rank.kickers[1])); затем кикер \(rankLabel(rank.kickers[2]))."
        case 3: return "Тройка \(rankLabel(rank.kickers[0])); затем кикеры: \(rank.kickers.dropFirst().map(rankLabel).joined(separator: ", "))."
        case 4: return "Старшая карта стрита — \(rankLabel(rank.kickers[0])). Туз может быть младшей картой в стрите 5–4–3–2–A."
        case 5: return "Во флеше сравниваются все пять рангов: \(labels)."
        case 6: return "Фулл-хаус: тройка \(rankLabel(rank.kickers[0])) и пара \(rankLabel(rank.kickers[1]))."
        case 7: return "Каре \(rankLabel(rank.kickers[0])); затем кикер \(rankLabel(rank.kickers[1]))."
        default: return "Стрит-флеш; старшая карта — \(rankLabel(rank.kickers[0]))."
        }
    }

    private static func comparisonReason(winner: HandRank, loser: HandRank) -> String {
        if winner.category != loser.category { return "\(winner.title) старше, чем \(loser.title)" }
        guard let index = winner.kickers.indices.first(where: { winner.kickers[$0] != loser.kickers[$0] }) else {
            return "категории и сравниваемые ранги совпали"
        }
        return "категории совпали; \(comparisonComponent(category: winner.category, index: index)) \(rankLabel(winner.kickers[index])) сильнее, чем \(rankLabel(loser.kickers[index]))"
    }

    private static func comparisonComponent(category: Int, index: Int) -> String {
        switch category {
        case 0: return "старшая карта №\(index + 1)"
        case 1: return index == 0 ? "пара" : "кикер №\(index)"
        case 2: return index == 0 ? "старшая пара" : (index == 1 ? "младшая пара" : "кикер")
        case 3: return index == 0 ? "тройка" : "кикер №\(index)"
        case 4, 8: return "старшая карта стрита"
        case 5: return "старшая карта флеша №\(index + 1)"
        case 6: return index == 0 ? "тройка фулл-хауса" : "пара фулл-хауса"
        default: return index == 0 ? "каре" : "кикер"
        }
    }

    private static func setNote(holeCards: [Card], rank: HandRank) -> String {
        guard rank.category == 3, holeCards[0].rank == holeCards[1].rank, holeCards[0].rank == rank.kickers[0] else { return "" }
        return " Карманная пара \(rankLabel(rank.kickers[0])) вместе с такой же картой на доске образует сет."
    }

    private static func rankLabel(_ rank: Int) -> String {
        switch rank { case 14: "A"; case 13: "K"; case 12: "Q"; case 11: "J"; default: String(rank) }
    }
}

public struct HandComparisonAttempt: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let question: HandComparisonQuestion
    public let answer: HandComparisonAnswer
    public let isCorrect: Bool

    public init(question: HandComparisonQuestion, answer: HandComparisonAnswer) {
        id = UUID()
        date = Date()
        self.question = question
        self.answer = answer
        isCorrect = question.isCorrect(answer)
    }

    public var isValid: Bool {
        let answerIsWellFormed: Bool
        switch (question.mode, answer) {
        case (.winner, .winner):
            answerIsWellFormed = true
        case (.bestFive, .bestFive(let cards)):
            answerIsWellFormed = cards.count == 5 && Set(cards).count == 5 && Set(cards).isSubset(of: Set(question.first + question.board))
        default:
            answerIsWellFormed = false
        }
        return answerIsWellFormed && question.isCorrect(answer) == isCorrect
    }
}

public enum HandComparisonLesson {
    fileprivate static let templateKeys: Set<String> = [
        "highcard", "pair", "twopair", "set", "wheel", "flush", "fullhouse", "quads", "straightflush", "boardsplit", "kicker", "straight"
    ]

    private struct Template {
        let key: String
        let first: [Card]
        let second: [Card]
        let board: [Card]
        let mode: HandComparisonMode
    }

    public static func questions(seed: UInt64) -> [HandComparisonQuestion] {
        let templates = baseTemplates
        return templates.enumerated().map { index, template in
            var generator = SeededGenerator(state: seed &+ UInt64(index) &* 0x9E3779B97F4A7C15)
            let suits = shuffledSuits(using: &generator)
            var first = template.first.map { permute($0, suits: suits) }
            var second = template.second.map { permute($0, suits: suits) }
            let board = template.board.map { permute($0, suits: suits) }
            if template.mode == .winner, generator.next() & 1 == 1 { swap(&first, &second) }
            let id = questionID(key: template.key, first: first, second: second, board: board, mode: template.mode)
            // Templates and their suit permutations have been constructed with valid, unique cards.
            return try! HandComparisonQuestion(id: id, first: first, second: second, board: board, mode: template.mode)
        }
    }

    private static func shuffledSuits(using generator: inout SeededGenerator) -> [Int] {
        var suits = [0, 1, 2, 3]
        for index in stride(from: suits.count - 1, through: 1, by: -1) {
            suits.swapAt(index, Int(generator.next() % UInt64(index + 1)))
        }
        return suits
    }

    private static func permute(_ card: Card, suits: [Int]) -> Card { Card(id: suits[card.suit] * 13 + card.rank - 2) }
    private static func card(_ rank: Int, _ suit: Int) -> Card { Card(id: suit * 13 + rank - 2) }
    private static func questionID(key: String, first: [Card], second: [Card], board: [Card], mode: HandComparisonMode) -> String {
        "hcmp-v1-\(key)-\(mode.rawValue)-\((first + second + board).map { String($0.id) }.joined(separator: "."))"
    }

    private static let baseTemplates: [Template] = [
        .init(key: "highcard", first: [card(14, 1), card(9, 3)], second: [card(12, 1), card(10, 3)], board: [card(2, 0), card(5, 1), card(8, 2), card(11, 3), card(13, 0)], mode: .bestFive),
        .init(key: "pair", first: [card(13, 1), card(3, 3)], second: [card(11, 1), card(14, 3)], board: [card(2, 0), card(7, 1), card(9, 2), card(11, 3), card(13, 0)], mode: .winner),
        .init(key: "twopair", first: [card(13, 1), card(11, 1)], second: [card(9, 1), card(7, 3)], board: [card(2, 0), card(7, 1), card(9, 2), card(11, 3), card(13, 0)], mode: .bestFive),
        .init(key: "set", first: [card(8, 1), card(8, 2)], second: [card(13, 1), card(11, 1)], board: [card(8, 0), card(2, 1), card(5, 2), card(11, 3), card(13, 0)], mode: .winner),
        .init(key: "wheel", first: [card(5, 1), card(13, 2)], second: [card(6, 1), card(7, 2)], board: [card(14, 0), card(2, 1), card(3, 2), card(4, 3), card(9, 0)], mode: .bestFive),
        .init(key: "flush", first: [card(14, 1), card(3, 1)], second: [card(9, 1), card(7, 1)], board: [card(2, 1), card(5, 1), card(8, 1), card(11, 3), card(13, 0)], mode: .winner),
        .init(key: "fullhouse", first: [card(13, 2), card(9, 1)], second: [card(2, 1), card(9, 2)], board: [card(13, 0), card(13, 1), card(2, 2), card(2, 3), card(9, 0)], mode: .bestFive),
        .init(key: "quads", first: [card(9, 3), card(14, 1)], second: [card(13, 1), card(13, 2)], board: [card(9, 0), card(9, 1), card(9, 2), card(2, 3), card(13, 0)], mode: .winner),
        .init(key: "straightflush", first: [card(10, 1), card(14, 1)], second: [card(11, 1), card(12, 1)], board: [card(6, 1), card(7, 1), card(8, 1), card(9, 1), card(2, 0)], mode: .bestFive),
        .init(key: "boardsplit", first: [card(2, 1), card(3, 2)], second: [card(4, 1), card(5, 2)], board: [card(14, 0), card(13, 0), card(12, 0), card(11, 0), card(10, 0)], mode: .winner),
        .init(key: "kicker", first: [card(14, 1), card(13, 2)], second: [card(14, 2), card(11, 1)], board: [card(12, 0), card(12, 1), card(7, 2), card(4, 3), card(2, 0)], mode: .winner),
        .init(key: "straight", first: [card(10, 1), card(9, 2)], second: [card(9, 1), card(8, 2)], board: [card(6, 0), card(7, 1), card(8, 0), card(2, 3), card(14, 0)], mode: .bestFive)
    ]
}
