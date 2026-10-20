import Foundation

/// Heads-up showdown share with all remaining boards equally likely; no further betting.
public enum EquityLessonError: Error { case invalidCards }

public struct KnownHandEquityQuestion: Sendable, Identifiable {
    public let id: String
    public let hero: [Card]
    public let opponent: [Card]
    public let board: [Card]

    public init(id: String, hero: [Card], opponent: [Card], board: [Card]) throws {
        let cards = hero + opponent + board
        guard hero.count == 2, opponent.count == 2, (3...4).contains(board.count),
              cards.allSatisfy({ (0..<52).contains($0.id) }), Set(cards).count == cards.count else {
            throw EquityLessonError.invalidCards
        }
        self.id=id; self.hero=hero; self.opponent=opponent; self.board=board
    }

    public func calculate() throws -> KnownHandEquityResult {
        let known=Set(hero + opponent + board)
        let remaining=(0..<52).map { Card(id:$0) }.filter { !known.contains($0) }
        var wins=0, ties=0, losses=0
        func evaluate(_ runout:[Card]) {
            let first=HandEvaluator.best(of:hero + board + runout)
            let second=HandEvaluator.best(of:opponent + board + runout)
            if first == second { ties += 1 }
            else if first > second { wins += 1 }
            else { losses += 1 }
        }
        for i in remaining.indices {
            try Task.checkCancellation()
            if board.count == 4 { evaluate([remaining[i]]) }
            else {
                for j in (i+1)..<remaining.count { evaluate([remaining[i],remaining[j]]) }
            }
        }
        return KnownHandEquityResult(wins:wins,ties:ties,losses:losses)
    }

    public static let examples: [Self] = [
        try! .init(id:"equity-known-flop-v1",hero:[Card(id:12),Card(id:25)],opponent:[Card(id:11),Card(id:24)],board:[Card(id:0),Card(id:18),Card(id:33)]),
        try! .init(id:"equity-known-turn-v1",hero:[Card(id:12),Card(id:24)],opponent:[Card(id:38),Card(id:50)],board:[Card(id:8),Card(id:22),Card(id:36),Card(id:39)])
    ]
}

public struct KnownHandEquityResult: Sendable, Equatable {
    public let wins: Int
    public let ties: Int
    public let losses: Int
    public var total: Int { wins + ties + losses }
    public var equityPercent: Double { 100 * (Double(wins) + Double(ties)/2) / Double(total) }
    public var explanation: [String] {
        ["Победы: \(wins) · ничьи: \(ties) · поражения: \(losses). Всего исходов: \(total).",
         "Каждая победа даёт целый банк, ничья — половину. Equity = (\(wins) + \(ties) / 2) / \(total) × 100 = \(String(format:"%.2f",equityPercent)) %.",
         "Доля побед: \(String(format:"%.2f",100 * Double(wins)/Double(total))) %. Доля ничьих: \(String(format:"%.2f",100 * Double(ties)/Double(total))) %.",
         "Это средняя доля одного общего банка к риверу при двух открытых руках и равновероятных оставшихся картах. Будущие ставки, фолд, рейк и побочные банки исключены условиями. Исход отдельной раздачи остаётся случайным."]
    }
}

public extension PracticeAttempt {
    init(question:KnownHandEquityQuestion, result:KnownHandEquityResult, answer:Double) {
        self.init(questionID:question.id,answer:answer,expectedPercent:result.equityPercent)
    }
}
