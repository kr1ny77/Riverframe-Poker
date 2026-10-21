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
    @Published public var errorMessage: String?
    private let history: PracticeHistory
    private var loadFailed = false
    public var course: LearningCourseSnapshot {
        LearningCourseSnapshot(archive:PracticeArchive(attempts:attempts,comparisons:comparisons,positions:positions,evCalls:evCalls,blockers:blockers,foundations:foundations))
    }

    public var catalog: CourseCatalogSnapshot { CourseCatalogSnapshot(course: course, foundations: foundations) }

    public init(fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("PokerPractice",isDirectory:true)
        history=PracticeHistory(fileURL:fileURL ?? directory.appendingPathComponent("practice-v1.json"))
        do {
            let archive = try history.loadArchive()
            attempts=archive.attempts; comparisons=archive.comparisons;positions=archive.positions;evCalls=archive.evCalls;blockers=archive.blockers;foundations=archive.foundations
        }
        catch {
            loadFailed=true
            errorMessage="Историю прочитать не удалось. Исходный файл сохранён. Повторите загрузку или явно очистите историю в настройках."
        }
    }
    public func reload() {
        do {
            let archive = try history.loadArchive()
            attempts=archive.attempts; comparisons=archive.comparisons;positions=archive.positions;evCalls=archive.evCalls;blockers=archive.blockers;foundations=archive.foundations
            loadFailed=false;errorMessage=nil
        }
        catch { loadFailed=true;errorMessage="Повторная загрузка не удалась: \(error.localizedDescription)" }
    }
    public func record(_ attempt:PracticeAttempt) throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        guard !attempts.contains(where:{$0.id==attempt.id}) else { return }
        guard !comparisons.contains(where:{$0.id==attempt.id}), !positions.contains(where:{$0.id==attempt.id}), !evCalls.contains(where:{$0.id==attempt.id}), !blockers.contains(where:{$0.id==attempt.id}), !foundations.contains(where:{$0.id==attempt.id}) else { throw CocoaError(.fileWriteUnknown) }
        let next=attempts+[attempt]
        do { try history.saveArchive(PracticeArchive(attempts:next,comparisons:comparisons,positions:positions,evCalls:evCalls,blockers:blockers,foundations:foundations));attempts=next;errorMessage=nil }
        catch { errorMessage="Результат не сохранён: \(error.localizedDescription)";throw error }
    }
    public func record(_ attempt:HandComparisonAttempt) throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        guard attempt.isValid else { throw CocoaError(.fileWriteUnknown) }
        guard !comparisons.contains(where:{$0.id==attempt.id}) else { return }
        guard !attempts.contains(where:{$0.id==attempt.id}), !positions.contains(where:{$0.id==attempt.id}), !evCalls.contains(where:{$0.id==attempt.id}), !blockers.contains(where:{$0.id==attempt.id}), !foundations.contains(where:{$0.id==attempt.id}) else { throw CocoaError(.fileWriteUnknown) }
        let next=comparisons+[attempt]
        do { try history.saveArchive(PracticeArchive(attempts:attempts,comparisons:next,positions:positions,evCalls:evCalls,blockers:blockers,foundations:foundations));comparisons=next;errorMessage=nil }
        catch { errorMessage="Результат не сохранён: \(error.localizedDescription)";throw error }
    }
    public func record(_ attempt:PositionAttempt) throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        guard attempt.isValid else { throw CocoaError(.fileWriteUnknown) }
        guard !positions.contains(where:{$0.id==attempt.id}) else { return }
        guard !attempts.contains(where:{$0.id==attempt.id}), !comparisons.contains(where:{$0.id==attempt.id}), !evCalls.contains(where:{$0.id==attempt.id}), !blockers.contains(where:{$0.id==attempt.id}), !foundations.contains(where:{$0.id==attempt.id}) else { throw CocoaError(.fileWriteUnknown) }
        let next=positions+[attempt]
        do { try history.saveArchive(PracticeArchive(attempts:attempts,comparisons:comparisons,positions:next,evCalls:evCalls,blockers:blockers,foundations:foundations));positions=next;errorMessage=nil }
        catch { errorMessage="Результат не сохранён: \(error.localizedDescription)";throw error }
    }
    public func record(_ attempt:EVCallAttempt) throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        guard attempt.isValid else { throw CocoaError(.fileWriteUnknown) }
        guard !evCalls.contains(where:{$0.id==attempt.id}) else { return }
        guard !attempts.contains(where:{$0.id==attempt.id}), !comparisons.contains(where:{$0.id==attempt.id}), !positions.contains(where:{$0.id==attempt.id}), !blockers.contains(where:{$0.id==attempt.id}), !foundations.contains(where:{$0.id==attempt.id}) else { throw CocoaError(.fileWriteUnknown) }
        let next=evCalls+[attempt]
        do { try history.saveArchive(PracticeArchive(attempts:attempts,comparisons:comparisons,positions:positions,evCalls:next,blockers:blockers,foundations:foundations));evCalls=next;errorMessage=nil }
        catch { errorMessage="Результат не сохранён: \(error.localizedDescription)";throw error }
    }
    public func record(_ attempt:BlockerAttempt) throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        guard attempt.isValid else { throw CocoaError(.fileWriteUnknown) }
        guard !blockers.contains(where:{$0.id==attempt.id}) else { return }
        guard !attempts.contains(where:{$0.id==attempt.id}), !comparisons.contains(where:{$0.id==attempt.id}), !positions.contains(where:{$0.id==attempt.id}), !evCalls.contains(where:{$0.id==attempt.id}), !foundations.contains(where:{$0.id==attempt.id}) else { throw CocoaError(.fileWriteUnknown) }
        let next=blockers+[attempt]
        do { try history.saveArchive(PracticeArchive(attempts:attempts,comparisons:comparisons,positions:positions,evCalls:evCalls,blockers:next,foundations:foundations));blockers=next;errorMessage=nil }
        catch { errorMessage="Результат не сохранён: \(error.localizedDescription)";throw error }
    }
    public func record(_ attempt: FoundationAttempt) throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
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
        let legacyIDs = attempts.map(\.id) + comparisons.map(\.id) + positions.map(\.id) + evCalls.map(\.id) + blockers.map(\.id)
        guard !legacyIDs.contains(attempt.id) else { throw CocoaError(.fileWriteUnknown) }
        let next = foundations + [attempt]
        do {
            try history.saveArchive(PracticeArchive(attempts: attempts, comparisons: comparisons, positions: positions,
                                                   evCalls: evCalls, blockers: blockers, foundations: next))
            foundations = next; errorMessage = nil
        } catch { errorMessage = "Результат не сохранён: \(error.localizedDescription)"; throw error }
    }
    public func clear() throws {
        do { try history.saveArchive(PracticeArchive());attempts=[];comparisons=[];positions=[];evCalls=[];blockers=[];foundations=[];loadFailed=false;errorMessage=nil }
        catch { errorMessage="Очистить историю не удалось: \(error.localizedDescription)";throw error }
    }
}
