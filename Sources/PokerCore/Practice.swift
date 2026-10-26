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
    /// A diagnostic shares the UUID of the incorrect answer that produced it.
    /// It is learning data, separate from the virtual-chip game history.
    public var diagnostics: [LearningDiagnostic]
    public init(attempts: [PracticeAttempt] = [], comparisons: [HandComparisonAttempt] = [], positions: [PositionAttempt] = [], evCalls: [EVCallAttempt] = [], blockers: [BlockerAttempt] = [], foundations: [FoundationAttempt] = [], diagnostics: [LearningDiagnostic] = []) {
        self.attempts = attempts
        self.comparisons = comparisons
        self.positions = positions
        self.evCalls = evCalls
        self.blockers = blockers
        self.foundations = foundations
        self.diagnostics = diagnostics
    }
}

/// Version 7 adds local learning diagnostics. Versions 1–6 remain readable;
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
        let diagnostics: [LearningDiagnostic]?
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
        case 1: validStructure = envelope.comparisons == nil && envelope.positions == nil && envelope.evCalls == nil && envelope.blockers == nil && envelope.diagnostics == nil
        case 2: validStructure = envelope.comparisons != nil && envelope.positions == nil && envelope.evCalls == nil && envelope.blockers == nil && envelope.diagnostics == nil
        case 3: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls == nil && envelope.blockers == nil && envelope.diagnostics == nil
        case 4: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls != nil && envelope.blockers == nil && envelope.diagnostics == nil
        case 5: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls != nil && envelope.blockers != nil && envelope.foundations == nil && envelope.diagnostics == nil
        case 6: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls != nil && envelope.blockers != nil && envelope.foundations != nil && envelope.diagnostics == nil
        case 7: validStructure = envelope.comparisons != nil && envelope.positions != nil && envelope.evCalls != nil && envelope.blockers != nil && envelope.foundations != nil && envelope.diagnostics != nil
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
        let archive = PracticeArchive(attempts:envelope.attempts, comparisons:comparisons, positions:positions,
                                      evCalls:evCalls, blockers:blockers, foundations:foundations,
                                      diagnostics:envelope.diagnostics ?? [])
        guard Self.hasValidDiagnostics(archive) else { throw CocoaError(.fileReadCorruptFile) }
        return Self.normalized(archive)
    }
    /// Compatibility entry point: numeric updates preserve any saved comparisons.
    public func save(_ attempts:[PracticeAttempt]) throws {
        let archive = try loadArchive()
        try saveArchive(PracticeArchive(attempts:attempts, comparisons:archive.comparisons, positions:archive.positions,
                                        evCalls:archive.evCalls, blockers:archive.blockers, foundations:archive.foundations,
                                        diagnostics:archive.diagnostics.filter { diagnostic in
                                            !archive.attempts.contains(where: { $0.id == diagnostic.id }) || attempts.contains(where: { $0.id == diagnostic.id })
                                        }))
    }
    public func saveArchive(_ archive: PracticeArchive) throws {
        try FileManager.default.createDirectory(at:fileURL.deletingLastPathComponent(),withIntermediateDirectories:true)
        guard Self.hasValidArchiveRecords(archive), Self.hasValidDiagnostics(archive) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let normalized = Self.normalized(archive)
        guard Self.hasValidDiagnostics(normalized) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let data=try JSONEncoder().encode(Envelope(version:7, attempts:normalized.attempts, comparisons:normalized.comparisons,
                                                    positions:normalized.positions, evCalls:normalized.evCalls,
                                                    blockers:normalized.blockers, foundations:normalized.foundations,
                                                    diagnostics:normalized.diagnostics))
        try data.write(to:fileURL,options:.atomic)
    }

    private static func normalized(_ archive: PracticeArchive) -> PracticeArchive {
        let retainedIDs = Set(archive.attempts.map(\.id) + archive.comparisons.map(\.id) + archive.positions.map(\.id)
            + archive.evCalls.map(\.id) + archive.blockers.map(\.id) + archive.foundations.map(\.id))
        let retained = archive.diagnostics.filter { retainedIDs.contains($0.id) }
        let catalog = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: archive), foundations: archive.foundations)
        let inferred = CourseLearning.inferredDiagnostics(catalog: catalog)
        var diagnosticByID: [UUID: LearningDiagnostic] = [:]
        for diagnostic in retained where diagnosticByID[diagnostic.id] == nil {
            diagnosticByID[diagnostic.id] = diagnostic
        }
        for diagnostic in inferred where diagnosticByID[diagnostic.id] == nil {
            diagnosticByID[diagnostic.id] = diagnostic
        }
        return PracticeArchive(attempts: archive.attempts, comparisons: archive.comparisons, positions: archive.positions,
                               evCalls: archive.evCalls, blockers: archive.blockers, foundations: archive.foundations,
                               diagnostics: diagnosticByID.values.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date })
    }

    private static func hasValidArchiveRecords(_ archive: PracticeArchive) -> Bool {
        let IDs = archive.attempts.map(\.id) + archive.comparisons.map(\.id) + archive.positions.map(\.id)
            + archive.evCalls.map(\.id) + archive.blockers.map(\.id) + archive.foundations.map(\.id)
        return Set(IDs).count == IDs.count
            && archive.attempts.allSatisfy { $0.answer.isFinite && (0...100).contains($0.answer)
                && $0.correctPercent.isFinite && (0...100).contains($0.correctPercent)
                && $0.isCorrect == (abs($0.answer - $0.correctPercent) <= 0.5) }
            && archive.comparisons.allSatisfy(\.isValid)
            && archive.positions.allSatisfy(\.isValid)
            && archive.evCalls.allSatisfy(\.isValid)
            && archive.blockers.allSatisfy(\.isValid)
            && archive.foundations.allSatisfy(\.isValid)
    }

    private static func hasValidDiagnostics(_ archive: PracticeArchive) -> Bool {
        guard Set(archive.diagnostics.map(\.id)).count == archive.diagnostics.count,
              archive.diagnostics.allSatisfy(\.isValid) else { return false }
        let recordIDs = Set(archive.attempts.map(\.id) + archive.comparisons.map(\.id) + archive.positions.map(\.id)
            + archive.evCalls.map(\.id) + archive.blockers.map(\.id) + archive.foundations.map(\.id))
        guard archive.diagnostics.allSatisfy({ recordIDs.contains($0.id) }) else { return false }
        let catalog = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: archive), foundations: archive.foundations)
        for diagnostic in archive.diagnostics {
            guard let observation = catalog.observations.first(where: { $0.id == diagnostic.id }) else { continue }
            guard !observation.isCorrect, observation.exerciseID == diagnostic.exerciseID, observation.date == diagnostic.date else {
                return false
            }
        }
        return true
    }
}
