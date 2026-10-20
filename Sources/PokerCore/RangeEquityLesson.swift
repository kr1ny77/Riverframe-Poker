import Foundation

public enum RangeEquityError: Error { case invalidWeight, invalidSize, duplicateHand }

/// One physical two-card combination. Weight is a relative probability mass
/// conditional on the displayed hero/board, in integer units 1...1000.
public struct WeightedOpponentHand: Identifiable, Sendable {
    public let cards: [Card]
    public let weight: Int
    public var id: String { cards.map(\.id).sorted().map(String.init).joined(separator:"-") }
    public init(cards:[Card],weight:Int) throws {
        guard (1...1000).contains(weight) else { throw RangeEquityError.invalidWeight }
        guard cards.count == 2, Set(cards).count == 2,
              cards.allSatisfy({(0..<52).contains($0.id)}) else { throw EquityLessonError.invalidCards }
        self.cards=cards;self.weight=weight
    }
}

public struct RangeEquityQuestion: Identifiable, Sendable {
    public let id: String
    public let hero: [Card]
    public let board: [Card]
    public let range: [WeightedOpponentHand]
    public var totalWeight: Int { range.reduce(0) { $0+$1.weight } }
    public init(id:String,hero:[Card],board:[Card],range:[WeightedOpponentHand]) throws {
        guard (1...8).contains(range.count) else { throw RangeEquityError.invalidSize }
        guard Set(range.map(\.id)).count == range.count else { throw RangeEquityError.duplicateHand }
        for hand in range {
            _ = try KnownHandEquityQuestion(id:id,hero:hero,opponent:hand.cards,board:board)
        }
        self.id=id;self.hero=hero;self.board=board;self.range=range
    }
    public func calculate() throws -> RangeEquityResult {
        var rows:[RangeEquityRow]=[]
        for hand in range {
            try Task.checkCancellation()
            let question=try KnownHandEquityQuestion(id:id,hero:hero,opponent:hand.cards,board:board)
            rows.append(RangeEquityRow(hand:hand,outcomes:try question.calculate()))
        }
        return RangeEquityResult(rows:rows)
    }
    public static let examples:[Self] = [
        try! .init(id:"equity-range-flop-v1",hero:[Card(id:12),Card(id:25)],board:[Card(id:0),Card(id:18),Card(id:33)],range:[
            .init(cards:[Card(id:11),Card(id:24)],weight:3),
            .init(cards:[Card(id:10),Card(id:23)],weight:1)]),
        try! .init(id:"equity-range-turn-1to3-v1",hero:[Card(id:12),Card(id:24)],board:[Card(id:8),Card(id:22),Card(id:36),Card(id:39)],range:[
            .init(cards:[Card(id:38),Card(id:50)],weight:1),
            .init(cards:[Card(id:7),Card(id:20)],weight:3)]),
        try! .init(id:"equity-range-turn-3to1-v1",hero:[Card(id:12),Card(id:24)],board:[Card(id:8),Card(id:22),Card(id:36),Card(id:39)],range:[
            .init(cards:[Card(id:38),Card(id:50)],weight:3),
            .init(cards:[Card(id:7),Card(id:20)],weight:1)])
    ]
}

public struct RangeEquityRow: Identifiable, Sendable {
    public let hand: WeightedOpponentHand
    public let outcomes: KnownHandEquityResult
    public var id: String { hand.id }
}

public struct RangeEquityResult: Sendable {
    public let rows: [RangeEquityRow]
    /// Actual distinct (opponent hand, board completion) evaluations.
    public var evaluatedOutcomes: Int { rows.reduce(0) { $0+$1.outcomes.total } }
    public var totalWeight: Int { rows.reduce(0) { $0+$1.hand.weight } }
    public var weightedWins: Int { rows.reduce(0) { $0+$1.hand.weight*$1.outcomes.wins } }
    public var weightedTies: Int { rows.reduce(0) { $0+$1.hand.weight*$1.outcomes.ties } }
    public var weightedLosses: Int { rows.reduce(0) { $0+$1.hand.weight*$1.outcomes.losses } }
    public var weightedTotal: Int { weightedWins+weightedTies+weightedLosses }
    // Each legal hand has the same runout count (990 on flop, 44 on turn).
    // Integer half-pot units retain the exact rational share until display.
    public var equityPercent: Double { 100*Double(2*weightedWins+weightedTies)/Double(2*weightedTotal) }
    public var explanation: [String] {
        ["Точный перебор: \(rows.count) комбинации, по \(rows[0].outcomes.total) продолжений на каждую. Рассмотрено исходов: \(evaluatedOutcomes).",
         "Для каждой возможной руки исключены её две карты, карты Hero и доски. Карты остальных альтернативных рук остаются возможными: у соперника одна из перечисленных рук.",
         "Вес руки / сумма весов — её вероятность в этой учебной модели. Сумма весов: \(totalWeight). Итоговая equity — среднее equity отдельных рук с этими вероятностями.",
         "Взвешенные единицы: победы \(weightedWins), ничьи \(weightedTies), поражения \(weightedLosses); всего \(weightedTotal). Equity = (\(weightedWins) + \(weightedTies)/2) / \(weightedTotal) × 100 = \(String(format:"%.2f",equityPercent)) %.",
         "Взвешенные единицы учитывают относительную массу, а число реально рассмотренных исходов равно \(evaluatedOutcomes). Все оставшиеся карты внутри каждой ветви равновероятны.",
         "Результат зависит от выбранных рук и весов. Диапазон — заданное учебное предположение. Один общий банк, два игрока, ставки завершены; рейк и побочные банки исключены условиями. Equity описывает среднюю долю банка в этой модели."]
    }
}

public extension PracticeAttempt {
    init(question:RangeEquityQuestion,result:RangeEquityResult,answer:Double) {
        self.init(questionID:question.id,answer:answer,expectedPercent:result.equityPercent)
    }
}
