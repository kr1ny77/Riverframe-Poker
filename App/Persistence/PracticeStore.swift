import Foundation
import Combine
import PokerCore

@MainActor
public final class PracticeStore: ObservableObject {
    @Published public private(set) var attempts: [PracticeAttempt] = []
    @Published public private(set) var comparisons: [HandComparisonAttempt] = []
    @Published public private(set) var positions: [PositionAttempt] = []
    @Published public private(set) var evCalls: [EVCallAttempt] = []
    @Published public private(set) var blockers: [BlockerAttempt] = []
    @Published public private(set) var foundations: [FoundationAttempt] = []
    @Published public private(set) var diagnostics: [LearningDiagnostic] = []
    @Published public var errorMessage: String?

    private let history: PracticeHistory
    private var loadFailed = false

    public var course: LearningCourseSnapshot { LearningCourseSnapshot(archive: archive) }
    public var catalog: CourseCatalogSnapshot { CourseCatalogSnapshot(course: course, foundations: foundations) }

    public init(fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokerPractice", isDirectory: true)
        history = PracticeHistory(fileURL: fileURL ?? directory.appendingPathComponent("practice-v1.json"))
        do {
            replace(with: try history.loadArchive())
        } catch {
            loadFailed = true
            errorMessage = "Историю прочитать не удалось. Исходный файл сохранён. Повторите загрузку или явно очистите историю в настройках."
        }
    }

    public func reload() {
        do {
            replace(with: try history.loadArchive())
            loadFailed = false
            errorMessage = nil
        } catch {
            loadFailed = true
            errorMessage = "Повторная загрузка не удалась: \(error.localizedDescription)"
        }
    }

    public func record(_ attempt: PracticeAttempt) throws {
        try requireWritable()
        guard !attempts.contains(where: { $0.id == attempt.id }) else { return }
        guard !containsOtherRecord(id: attempt.id) else { throw CocoaError(.fileWriteUnknown) }
        var next = archive
        next.attempts.append(attempt)
        try persist(next)
    }

    public func record(_ attempt: HandComparisonAttempt) throws {
        try requireWritable()
        guard attempt.isValid else { throw CocoaError(.fileWriteUnknown) }
        guard !comparisons.contains(where: { $0.id == attempt.id }) else { return }
        guard !containsOtherRecord(id: attempt.id) else { throw CocoaError(.fileWriteUnknown) }
        var next = archive
        next.comparisons.append(attempt)
        try persist(next)
    }

    public func record(_ attempt: PositionAttempt) throws {
        try requireWritable()
        guard attempt.isValid else { throw CocoaError(.fileWriteUnknown) }
        guard !positions.contains(where: { $0.id == attempt.id }) else { return }
        guard !containsOtherRecord(id: attempt.id) else { throw CocoaError(.fileWriteUnknown) }
        var next = archive
        next.positions.append(attempt)
        try persist(next)
    }

    public func record(_ attempt: EVCallAttempt) throws {
        try requireWritable()
        guard attempt.isValid else { throw CocoaError(.fileWriteUnknown) }
        guard !evCalls.contains(where: { $0.id == attempt.id }) else { return }
        guard !containsOtherRecord(id: attempt.id) else { throw CocoaError(.fileWriteUnknown) }
        var next = archive
        next.evCalls.append(attempt)
        try persist(next)
    }

    public func record(_ attempt: BlockerAttempt) throws {
        try requireWritable()
        guard attempt.isValid else { throw CocoaError(.fileWriteUnknown) }
        guard !blockers.contains(where: { $0.id == attempt.id }) else { return }
        guard !containsOtherRecord(id: attempt.id) else { throw CocoaError(.fileWriteUnknown) }
        var next = archive
        next.blockers.append(attempt)
        try persist(next)
    }

    public func record(_ attempt: FoundationAttempt) throws {
        try requireWritable()
        guard attempt.isValid, let exercise = FoundationLesson.exercise(attempt.exerciseID),
              exercise.contentVersion == attempt.contentVersion,
              exercise.answer.correctResponse == attempt.expected,
              exercise.answer.tolerance == attempt.tolerance else { throw CocoaError(.fileWriteUnknown) }
        if case .choice(let options, _) = exercise.answer {
            guard case .choice(let index) = attempt.response, options.indices.contains(index) else { throw CocoaError(.fileWriteUnknown) }
        }
        if let existing = foundations.first(where: { $0.id == attempt.id }) {
            guard existing == attempt else { throw CocoaError(.fileWriteUnknown) }
            return
        }
        guard !containsOtherRecord(id: attempt.id) else { throw CocoaError(.fileWriteUnknown) }
        var next = archive
        next.foundations.append(attempt)
        try persist(next)
    }

    /// Replaces the educational label of one persisted wrong answer. The answer,
    /// timestamp and exercise identity remain unchanged.
    public func classifyError(attemptID: UUID, kind: LearningErrorKind) throws {
        try requireWritable()
        guard let existing = diagnostics.first(where: { $0.id == attemptID }) else { throw CocoaError(.fileWriteUnknown) }
        var next = archive
        guard let index = next.diagnostics.firstIndex(where: { $0.id == attemptID }) else { throw CocoaError(.fileWriteUnknown) }
        next.diagnostics[index] = LearningDiagnostic(sourceAttemptID: existing.id, exerciseID: existing.exerciseID,
                                                     date: existing.date, kind: kind)
        try persist(next)
    }

    public func learning(now: Date = Date()) -> CourseLearningSnapshot {
        CourseLearningSnapshot(catalog: catalog, diagnostics: diagnostics, now: now)
    }

    public func clear() throws {
        do {
            try persist(PracticeArchive())
            loadFailed = false
            errorMessage = nil
        } catch {
            errorMessage = "Очистить историю не удалось: \(error.localizedDescription)"
            throw error
        }
    }

    private var archive: PracticeArchive {
        PracticeArchive(attempts: attempts, comparisons: comparisons, positions: positions, evCalls: evCalls,
                        blockers: blockers, foundations: foundations, diagnostics: diagnostics)
    }

    private func requireWritable() throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
    }

    private func containsOtherRecord(id: UUID) -> Bool {
        attempts.contains(where: { $0.id == id }) || comparisons.contains(where: { $0.id == id })
            || positions.contains(where: { $0.id == id }) || evCalls.contains(where: { $0.id == id })
            || blockers.contains(where: { $0.id == id }) || foundations.contains(where: { $0.id == id })
    }

    /// The history validates and writes the complete archive first. Published
    /// arrays change only after that atomic write succeeds.
    private func persist(_ next: PracticeArchive) throws {
        do {
            try history.saveArchive(next)
            replace(with: normalized(next))
            errorMessage = nil
        } catch {
            errorMessage = "Результат не сохранён: \(error.localizedDescription)"
            throw error
        }
    }

    private func replace(with archive: PracticeArchive) {
        attempts = archive.attempts
        comparisons = archive.comparisons
        positions = archive.positions
        evCalls = archive.evCalls
        blockers = archive.blockers
        foundations = archive.foundations
        diagnostics = archive.diagnostics
    }

    private func normalized(_ archive: PracticeArchive) -> PracticeArchive {
        let recordIDs = Set(archive.attempts.map(\.id) + archive.comparisons.map(\.id) + archive.positions.map(\.id)
            + archive.evCalls.map(\.id) + archive.blockers.map(\.id) + archive.foundations.map(\.id))
        var diagnosticByID: [UUID: LearningDiagnostic] = [:]
        for diagnostic in archive.diagnostics where recordIDs.contains(diagnostic.id) && diagnosticByID[diagnostic.id] == nil {
            diagnosticByID[diagnostic.id] = diagnostic
        }
        let catalog = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: archive), foundations: archive.foundations)
        for diagnostic in CourseLearning.inferredDiagnostics(catalog: catalog) where diagnosticByID[diagnostic.id] == nil {
            diagnosticByID[diagnostic.id] = diagnostic
        }
        return PracticeArchive(attempts: archive.attempts, comparisons: archive.comparisons, positions: archive.positions,
                               evCalls: archive.evCalls, blockers: archive.blockers, foundations: archive.foundations,
                               diagnostics: diagnosticByID.values.sorted {
                                   $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
                               })
    }
}
