import Foundation

public enum EVDecision: String, Codable, CaseIterable, Sendable {
    case fold, call
    public var title: String { rawValue.capitalized }
}

public enum EVCallError: Error { case invalidCards, invalidAmounts, invalidRange, unknownQuestion }

/// River-only heads-up cash model: facing an all-in, one eligible pot, no rake.
public struct EVCallQuestion: Identifiable, Sendable {
    public let id: String
    public let hero: [Card]
    public let board: [Card]
    public let range: [WeightedOpponentHand]
    public let potBefore: Int64
    public let opponentBet: Int64
    public var callAmount: Int64 { opponentBet }
    public var finalPot: Int64 { potBefore + opponentBet + callAmount }
    public var thresholdPercent: Double {
        PotOddsQuestion(id:id,potBefore:potBefore,opponentBet:opponentBet).correctPercent
    }
    public static let conditions = "NLHE cash · ривер · Hero BTN против BB, остальные сфолдили. Один общий банк, рейк 0, анте 0. BB ставит весь остаток стека; Hero покрывает ровно сумму колла. Будущая торговля завершится коллом или фолдом. Все суммы — виртуальные фишки."
    public static let scope = "Диапазон и веса заданы для обучения после ставки BB с учётом карт Hero и доски. Рекомендация относится только к этой модели. Для реального решения потребуется обоснованная оценка диапазона."

    public init(id:String,hero:[Card],board:[Card],range:[WeightedOpponentHand],potBefore:Int64,opponentBet:Int64) throws {
        guard (1...1_000_000_000).contains(potBefore), potBefore.isMultiple(of:2), (1...1_000_000_000).contains(opponentBet) else { throw EVCallError.invalidAmounts }
        guard (1...8).contains(range.count), Set(range.map(\.id)).count == range.count else { throw EVCallError.invalidRange }
        guard hero.count == 2, board.count == 5 else { throw EVCallError.invalidCards }
        for hand in range {
            let cards=hero+board+hand.cards
            guard cards.allSatisfy({ (0..<52).contains($0.id) }), Set(cards).count == cards.count else { throw EVCallError.invalidCards }
        }
        self.id=id;self.hero=hero;self.board=board;self.range=range;self.potBefore=potBefore;self.opponentBet=opponentBet
    }
    public var result: EVCallResult {
        let heroRank=HandEvaluator.best(of:hero+board)
        var wins=0, ties=0, losses=0
        for hand in range {
            let opponentRank=HandEvaluator.best(of:hand.cards+board)
            if heroRank == opponentRank { ties+=hand.weight }
            else if heroRank > opponentRank { wins+=hand.weight }
            else { losses+=hand.weight }
        }
        return EVCallResult(weightedWins:wins,weightedTies:ties,weightedLosses:losses,finalPot:finalPot,callAmount:callAmount)
    }
    public static let examples: [Self] = {
        let hero=[Card(id:12),Card(id:36)] // A♠ Q♦
        let board=[Card(id:25),Card(id:44),Card(id:28),Card(id:0),Card(id:20)] // A♥ 7♣ 4♦ 2♠ 9♥
        let win=[Card(id:38),Card(id:22)], loss=[Card(id:51),Card(id:50)], tie=[Card(id:51),Card(id:49)]
        return [
            try! .init(id:"ev-call-positive-v1",hero:hero,board:board,range:[.init(cards:win,weight:2),.init(cards:loss,weight:3)],potBefore:100,opponentBet:50),
            try! .init(id:"ev-call-negative-v1",hero:hero,board:board,range:[.init(cards:win,weight:1),.init(cards:loss,weight:4)],potBefore:100,opponentBet:50),
            try! .init(id:"ev-call-zero-v1",hero:hero,board:board,range:[.init(cards:loss,weight:1),.init(cards:tie,weight:1)],potBefore:100,opponentBet:50)
        ]
    }()
}

public struct EVCallResult: Sendable {
    public let weightedWins: Int
    public let weightedTies: Int
    public let weightedLosses: Int
    public let finalPot: Int64
    public let callAmount: Int64
    public var totalWeight: Int { weightedWins+weightedTies+weightedLosses }
    public var denominator: Int64 { 2*Int64(totalWeight) }
    public var equityPercent: Double { 100*Double(2*weightedWins+weightedTies)/Double(denominator) }
    /// Exact signed numerator; the zero decision uses integer equality.
    public var callEVNumerator: Int64 { Int64(2*weightedWins+weightedTies)*finalPot-denominator*callAmount }
    public var callEV: Double { Double(callEVNumerator)/Double(denominator) }
    public var foldEV: Double { 0 }
    public var recommendation: String {
        callEVNumerator == 0 ? "Call и Fold равноценны по EV в этой модели." : (callEVNumerator > 0 ? "Call даёт больший EV в этой модели." : "Fold даёт больший EV в этой модели.")
    }
    public func accepts(_ decision:EVDecision) -> Bool {
        callEVNumerator == 0 || (decision == .call ? callEVNumerator > 0 : callEVNumerator < 0)
    }
    public var signedEV: String { String(format:"%+.2f",callEV) }
    public func explanation(potBefore:Int64,opponentBet:Int64) -> [String] {
        ["Отсчёт — стек Hero сейчас, перед решением. Уже внесённые фишки входят в банк. EV(Fold) = 0: дополнительный расход и выплата Hero равны нулю.",
         "После ставки в банке \(potBefore) + \(opponentBet) = \(potBefore+opponentBet). Колл C = \(callAmount); итоговый банк F = \(potBefore) + \(opponentBet) + \(callAmount) = \(finalPot).",
         "Equity e = (\(weightedWins) + \(weightedTies)/2) / \(totalWeight) = \(String(format:"%.2f",equityPercent)) %. Это точное взвешивание \(totalWeight) единиц вероятностной массы, включая половину банка при ничьей.",
         "EV(Call) = e × F − C = \(String(format:"%.4f",equityPercent/100)) × \(finalPot) − \(callAmount) = \(signedEV) фишки. Порог из pot odds: C/F = \(callAmount)/\(finalPot) = \(String(format:"%.2f",100*Double(callAmount)/Double(finalPot))) %.",
         "Проверка по исходам: победа даёт +\(finalPot-callAmount), ничья +\(finalPot/2-callAmount), поражение −\(callAmount). EV — взвешенное среднее этих изменений стека.",
         recommendation,
         "Качество решения оцениваем по EV при заданном диапазоне. В отдельной раздаче прибыльный колл может проиграть, а убыточный — выиграть. Здесь результат вскрытия не разыгрывается; прогресс отражает выбор по модели."]
    }
}

public struct EVCallAttempt: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let questionID: String
    public let decision: EVDecision
    public let isCorrect: Bool
    public var question: EVCallQuestion? { EVCallQuestion.examples.first { $0.id == questionID } }
    public var isValid: Bool { question.map { isCorrect == $0.result.accepts(decision) } ?? false }
    public init(question:EVCallQuestion,decision:EVDecision) throws {
        guard let canonical=EVCallQuestion.examples.first(where:{$0.id == question.id}),
              canonical.hero == question.hero, canonical.board == question.board,
              canonical.potBefore == question.potBefore, canonical.opponentBet == question.opponentBet,
              canonical.range.map(\.id) == question.range.map(\.id),
              canonical.range.map(\.weight) == question.range.map(\.weight) else { throw EVCallError.unknownQuestion }
        id=UUID();date=Date();questionID=canonical.id;self.decision=decision;isCorrect=canonical.result.accepts(decision)
    }
}
