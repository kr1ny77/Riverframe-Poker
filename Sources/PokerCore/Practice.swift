import Foundation

public struct PotOddsQuestion: Identifiable, Codable, Sendable {
    public let id: String
    public let potBefore: Int64
    public let opponentBet: Int64
    public var callAmount: Int64 { opponentBet }
    public var finalPot: Int64 { potBefore + opponentBet + callAmount }
    public var correctPercent: Double { 100 * Double(callAmount) / Double(finalPot) }
    public var explanation: [String] {
        ["До ставки соперника в банке \(potBefore) фишек.",
         "Соперник поставил \(opponentBet). Сейчас в банке \(potBefore + opponentBet).",
         "Для колла нужно добавить \(callAmount). После колла банк составит \(finalPot).",
         "Порог эквити = цена колла / итоговый банк: \(callAmount) / \(finalPot) × 100 = \(String(format: "%.1f", correctPercent)) %.",
         "Это порог одного колла при завершённых ставках, без рейка и дальнейших расходов. Вероятность выигрыша зависит от рук и диапазонов; здесь она не задана."]
    }
    public static let examples: [Self] = [
        .init(id:"pot-100-bet-50-v1",potBefore:100,opponentBet:50),
        .init(id:"pot-120-bet-120-v1",potBefore:120,opponentBet:120),
        .init(id:"pot-200-bet-50-v1",potBefore:200,opponentBet:50)
    ]
}

public struct PracticeAttempt: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let date: Date
    public let questionID: String
    public let answer: Double
    public let correctPercent: Double
    public let isCorrect: Bool
    public init(question: PotOddsQuestion, answer: Double) {
        self.init(questionID:question.id, answer:answer, expectedPercent:question.correctPercent)
    }
    init(questionID: String, answer: Double, expectedPercent: Double) {
        precondition(answer.isFinite && (0...100).contains(answer))
        precondition(expectedPercent.isFinite && (0...100).contains(expectedPercent))
        id=UUID(); date=Date(); self.questionID=questionID
        self.answer=answer; correctPercent=expectedPercent
        isCorrect=abs(answer-expectedPercent)<=0.5
    }
}

public struct PracticeArchive: Sendable, Equatable {
    public var attempts: [PracticeAttempt]
    public var comparisons: [HandComparisonAttempt]
    public var positions: [PositionAttempt]
    public var evCalls: [EVCallAttempt]
    public var blockers: [BlockerAttempt]
    public var foundations: [FoundationAttempt]
    public init(attempts: [PracticeAttempt] = [], comparisons: [HandComparisonAttempt] = [], positions: [PositionAttempt] = [], evCalls: [EVCallAttempt] = [], blockers: [BlockerAttempt] = [], foundations: [FoundationAttempt] = []) {
        self.attempts = attempts
        self.comparisons = comparisons
        self.positions = positions
        self.evCalls = evCalls
        self.blockers = blockers
        self.foundations = foundations
    }
}

/// Version 6 adds typed foundation answers. Versions 1–5 remain readable;
/// a successful write migrates atomically and preserves all lesson categories.
public struct PracticeHistory: Sendable {
    private struct Envelope: Codable {
        let version: Int
        let attempts: [PracticeAttempt]
        let comparisons: [HandComparisonAttempt]?
        let positions: [PositionAttempt]?
        let evCalls: [EVCallAttempt]?
        let blockers: [BlockerAttempt]?
        let foundations: [FoundationAttempt]?
    }
    public let fileURL: URL
    public init(fileURL:URL) { self.fileURL=fileURL }
    public func load() throws -> [PracticeAttempt] {
        try loadArchive().attempts
    }
    public func loadArchive() throws -> PracticeArchive {
        guard FileManager.default.fileExists(atPath:fileURL.path) else { return PracticeArchive() }
        let data=try Data(contentsOf:fileURL)
        let envelope=try JSONDecoder().decode(Envelope.self,from:data)
        let validStructure: Bool
        switch envelope.version {
        case 1: validStructure = envelope.comparisons == nil && envelope.positions == nil && envelope.evCalls == nil && envelope.blockers == nil
        case 2: validStructure = envelope.comparisons != nil && envelope.positions == nil && envelope.evCalls == nil && envelope.blockers == nil
        case 3: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls == nil && envelope.blockers == nil
        case 4: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls != nil && envelope.blockers == nil
        case 5: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls != nil && envelope.blockers != nil && envelope.foundations == nil
        case 6: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls != nil && envelope.blockers != nil && envelope.foundations != nil
        default: validStructure = false
        }
        guard validStructure, (envelope.version >= 6 || envelope.foundations == nil),
              envelope.attempts.allSatisfy({$0.answer.isFinite && (0...100).contains($0.answer) && $0.correctPercent.isFinite && (0...100).contains($0.correctPercent) && $0.isCorrect == (abs($0.answer-$0.correctPercent)<=0.5)}) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let comparisons = envelope.comparisons ?? []
        let positions = envelope.positions ?? []
        let evCalls = envelope.evCalls ?? []
        let blockers = envelope.blockers ?? []
        let foundations = envelope.foundations ?? []
        let ids = envelope.attempts.map(\.id) + comparisons.map(\.id) + positions.map(\.id) + evCalls.map(\.id) + blockers.map(\.id) + foundations.map(\.id)
        guard Set(ids).count == ids.count, comparisons.allSatisfy(\.isValid), positions.allSatisfy(\.isValid), evCalls.allSatisfy(\.isValid), blockers.allSatisfy(\.isValid), foundations.allSatisfy(\.isValid) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return PracticeArchive(attempts:envelope.attempts,comparisons:comparisons,positions:positions,evCalls:evCalls,blockers:blockers,foundations:foundations)
    }
    /// Compatibility entry point: numeric updates preserve any saved comparisons.
    public func save(_ attempts:[PracticeAttempt]) throws {
        let archive = try loadArchive()
        try saveArchive(PracticeArchive(attempts:attempts,comparisons:archive.comparisons,positions:archive.positions,evCalls:archive.evCalls,blockers:archive.blockers,foundations:archive.foundations))
    }
    public func saveArchive(_ archive: PracticeArchive) throws {
        try FileManager.default.createDirectory(at:fileURL.deletingLastPathComponent(),withIntermediateDirectories:true)
        let data=try JSONEncoder().encode(Envelope(version:6,attempts:archive.attempts,comparisons:archive.comparisons,positions:archive.positions,evCalls:archive.evCalls,blockers:archive.blockers,foundations:archive.foundations))
        try data.write(to:fileURL,options:.atomic)
    }
}
