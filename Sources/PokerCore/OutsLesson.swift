import Foundation

public enum LearningTopic: String, CaseIterable, Identifiable, Sendable {
    case potOdds, outs, knownHandEquity, rangeEquity, other
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .potOdds: "Шансы банка"
        case .outs: "Ауты и вероятность улучшения"
        case .knownHandEquity: "Equity против известной руки"
        case .rangeEquity: "Equity против диапазона"
        case .other: "Другие учебные задачи"
        }
    }
}

/// A fixed, explicitly scoped lesson. Uniform unknown cards, no replacement.
/// The event is obtaining at least five hearts among the hero's seven cards.
public struct FlushDrawLesson: Sendable {
    public static let standard = FlushDrawLesson()
    public let hero = [Card(id:25), Card(id:24)] // Ah Kh
    public let flop = [Card(id:23), Card(id:18), Card(id:39)] // Qh 7h 2c
    public var available: [Card] {
        let known=Set(hero+flop)
        return (0..<52).map(Card.init(id:)).filter { !known.contains($0) }
    }
    public var outs: [Card] { available.filter { $0.suit==1 } }
    public var questions: [FlushDrawQuestion] { [.init(horizon:.nextCard), .init(horizon:.byRiver)] }
    private init() {}

    /// Exhaustive combinations, not a random sample or rule-of-four approximation.
    public func counts(for horizon: FlushDrawQuestion.Horizon) -> (hits:Int,total:Int) {
        let unseen=available
        if horizon == .nextCard { return (outs.count,unseen.count) }
        var hits=0,total=0
        for a in 0..<(unseen.count-1) {
            for b in (a+1)..<unseen.count {
                total += 1
                if unseen[a].suit==1 || unseen[b].suit==1 { hits += 1 }
            }
        }
        return (hits,total)
    }
}

public struct FlushDrawQuestion: Identifiable, Sendable {
    public enum Horizon: Int, Sendable { case nextCard, byRiver }
    public let horizon: Horizon
    public var id: String { horizon == .nextCard ? "flush-outs-next-v1" : "flush-outs-river-v1" }
    public var title: String { horizon == .nextCard ? "Флеш на тёрне" : "Флеш к риверу" }
    public var prompt: String {
        horizon == .nextCard ? "Какова вероятность получить пятую черву следующей общей картой?" : "Какова вероятность получить хотя бы одну черву за две следующие общие карты?"
    }
    public var correctPercent: Double {
        let result=FlushDrawLesson.standard.counts(for:horizon)
        return 100 * Double(result.hits) / Double(result.total)
    }
    public var choices: [Double] { horizon == .nextCard ? [9,19.1,35,38.3] : [19.1,35,38.3,50] }
    public var explanation: [String] {
        let common=[
            "Известны 5 уникальных карт: две ваши и три на флопе. Неизвестных карт: 52 − 5 = 47.",
            "Всего 13 червей, из них 4 уже видны. Остаётся 13 − 4 = 9 аутов, которые дадут флеш."
        ]
        if horizon == .nextCard {
            return common + [
                "Каждая из 47 неизвестных карт одинаково вероятна на тёрне. Подходят 9 из них.",
                "Точный расчёт: 9 / 47 × 100 = 19,1489… %, округлённо 19,1 %.",
                "Для ривера после промаха останется 46 неизвестных карт; следующая часть урока учитывает оба открытия."
            ]
        }
        return common + [
            "После промаха на тёрне остаются 37 неподходящих карт из 46. Вероятность двух промахов: 38 / 47 × 37 / 46.",
            "Хотя бы одна черва: 1 − (38 / 47 × 37 / 46) = 34,9676… %, округлённо 35,0 %.",
            "Полный перебор даёт тот же ответ: всего C(47, 2) = 1 081 пара, подходят 378. 378 / 1 081 × 100 = 34,9676… %.",
            "Простое удвоение 19,1 % учитывало бы некоторые исходы дважды. Перебор рассматривает каждую пару ровно один раз."
        ]
    }
    public var modelNote: String {
        "Модель: равномерные неизвестные карты, выбор без возвращения. Карты соперника и burn-карты считаются неизвестными. Открытия тёрна и ривера гарантированы условием. Считаем сбор флеша; доля выигрыша против соперника требует отдельного расчёта equity."
    }
}

public extension PracticeAttempt {
    init(question: FlushDrawQuestion, answer: Double) {
        self.init(questionID:question.id, answer:answer, expectedPercent:question.correctPercent)
    }
    var topic: LearningTopic {
        if questionID.hasPrefix("equity-range-") { return .rangeEquity }
        if questionID.hasPrefix("equity-known-") { return .knownHandEquity }
        if questionID.hasPrefix("pot-") { return .potOdds }
        if questionID.hasPrefix("flush-outs-") { return .outs }
        return .other
    }
}
