import Foundation
import Testing
@testable import PokerCore

private let finalTopics: Set<CourseTopicID> = [.t41, .t42, .t43, .t44, .t48, .t51, .t52, .t53, .t54, .t55, .t56, .t57, .t58, .t59, .t60]

@Test func completedCourseCoversEveryTopicAndModuleWithUniqueRoutes() {
    #expect(CourseCatalog.contentVersion == 5)
    #expect(FoundationLesson.finalExercises.count == 45)
    #expect(CourseCatalog.allExerciseIDs.count == 226)
    #expect(CourseCatalog.topics.count == 60)
    #expect(CourseCatalog.modules.count == 18)
    #expect(Set(CourseCatalog.topics.map(\.id)) == Set(CourseTopicID.allCases))
    #expect(Set(FoundationLesson.finalExercises.map(\.topicID)) == finalTopics)
    #expect(Set(FoundationLesson.exercises.map(\.id)).count == FoundationLesson.exercises.count)
    #expect(CourseCatalog.allExerciseIDs.count == 181 + FoundationLesson.finalExercises.count)
    for topic in CourseCatalog.topics {
        #expect(!CourseCatalog.exerciseIDs(for: topic.id).isEmpty)
        #expect(CourseCatalog.modules.contains { $0.id == topic.moduleID })
        for prerequisite in topic.prerequisites { #expect(CourseCatalog.topics.contains { $0.id == prerequisite }) }
    }
    for topic in finalTopics {
        let tasks = CourseCatalog.foundations(for: topic)
        #expect(tasks.count >= 3)
        #expect(Set(tasks.map(\.purpose)) == Set(FoundationPurpose.allCases))
        for task in tasks {
            #expect(FoundationLesson.exercise(task.id)?.topicID == topic)
            #expect(task.contentVersion == 1)
            #expect(!task.context.isEmpty && !task.question.isEmpty && !task.explanation.isEmpty)
            #expect(!task.assumptions.isEmpty && !task.typicalError.isEmpty && !task.researchAnchor.isEmpty)
            #expect(!task.term.isEmpty && !task.method.isEmpty && !task.diagram.isEmpty)
            #expect(task.resultKind != .verifiedTable && task.resultKind != .monteCarlo)
            #expect(task.answer.accepts(task.answer.correctResponse))
            let wrong: FoundationResponse
            switch task.answer {
            case .number(let value, let tolerance): wrong = .number(value + max(1, 2 * tolerance))
            case .choice(let options, let correct): wrong = .choice((correct + 1) % options.count)
            }
            #expect(!task.answer.accepts(wrong))
            #expect(FoundationAttempt(exercise: task, response: wrong).isValid)
        }
    }
}

@Test func baseline181AndEveryFinalAttemptSurviveRestartAndRepeatedSave() throws {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/course-v4-all181.json")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Completion-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let target = directory.appendingPathComponent("history.json")
    let bytes = try Data(contentsOf: fixture)
    try bytes.write(to: target)
    let history = PracticeHistory(fileURL: target)
    let baseline = try history.loadArchive()
    #expect(try Data(contentsOf: target) == bytes)
    #expect(baseline.foundations.count == 138)
    #expect(LearningCourseSnapshot(archive: baseline).completedLessons == 8)
    #expect(CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: baseline), foundations: baseline.foundations).overallProgress.covered == 181)
    var next = baseline
    for (index, task) in FoundationLesson.finalExercises.enumerated() {
        next.foundations.append(FoundationAttempt(exercise: task, response: task.answer.correctResponse,
            date: Date(timeIntervalSinceReferenceDate: 300_000 + Double(index))))
    }
    try history.saveArchive(next)
    try history.saveArchive(next)
    let restored = try PracticeHistory(fileURL: target).loadArchive()
    #expect(restored == next)
    #expect(Array(restored.foundations.prefix(138)) == baseline.foundations)
    #expect(restored.attempts == baseline.attempts && restored.comparisons == baseline.comparisons)
    #expect(restored.positions == baseline.positions && restored.evCalls == baseline.evCalls && restored.blockers == baseline.blockers)
    #expect(LearningCourseSnapshot(archive: restored).completedLessons == 8)
    let snapshot = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: restored), foundations: restored.foundations)
    #expect(snapshot.ignoredRecords == 0)
    #expect(snapshot.overallProgress.covered == CourseCatalog.allExerciseIDs.count)
    for topic in finalTopics { #expect(snapshot.progress(for: topic).completedAvailableExercises) }
}

@Test func finalNumericKeysMatchIndependentExamples() throws {
    let keys: [String: Double] = [
        "E.foundation.t43.mixed-ev": 29.0 / 4,
        "E.foundation.t43.simplification-loss": 1.0 / 4,
        "E.foundation.t44.sample-rate": 100,
        "E.foundation.t44.interval": 63.32093162728073,
        "E.foundation.t48.ticket-fold": 5191.0 / 7900,
        "E.foundation.t48.ticket-call": 39.0 / 50,
        "E.foundation.t52.counterfactual-ev": -0.5,
        "E.foundation.t53.price-error": 25,
        "E.foundation.t56.fair-walk": 100,
        "E.foundation.t56.favorable-walk": 1.80715950214,
        "E.foundation.t57.observed-rate": 70,
        "E.foundation.t58.equal-likelihood": 20,
        "E.foundation.t58.bayes-update": 200.0 / 3,
        "E.foundation.t60.audit-price": 7.5
    ]
    let numeric = FoundationLesson.finalExercises.filter { if case .number = $0.answer { true } else { false } }
    #expect(Set(numeric.map { $0.id.rawValue }) == Set(keys.keys))
    for task in numeric {
        let expected = try #require(keys[task.id.rawValue])
        guard case .number(let actual, _) = task.answer else { continue }
        #expect(abs(actual - expected) < 0.000001, "Independent key: \(task.id.rawValue)")
    }
}

@Test func satelliteLedgerAndAffinePrizesUseIndependentBranches() throws {
    let bank = 2.0 + 19 + 19
    let win: [Double] = [50.0, 29 - 19 + bank, 19 - 19]
    let lose: [Double] = [50.0, 29 - 19, 19 - 19 + bank]
    let fold: [Double] = [50.0, 29, 19 + 2]
    #expect(win == [50, 50, 0] && lose == [50, 10, 40])
    func ticketB(_ stacks: [Double]) -> Double {
        let total = stacks.reduce(0, +)
        return stacks[1] / total + stacks[0] / total * stacks[1] / (stacks[1] + stacks[2])
            + stacks[2] / total * stacks[1] / (stacks[0] + stacks[1])
    }
    for stacks in [fold, win, lose] {
        #expect(stacks.reduce(0, +) == 100)
        let expected = ticketB(stacks)
        #expect(abs(try CourseICM.prizeEquities(stacks: stacks, payouts: [1,1,0])[1] - expected) < 1e-12)
        #expect(abs(try CourseICM.prizeEquities(stacks: stacks, payouts: [1,1,0.5])[1] - (0.5 + 0.5 * expected)) < 1e-12)
    }
    let threshold = (ticketB(fold) - ticketB(lose)) / (ticketB(win) - ticketB(lose))
    let transformedThreshold = ((0.5 + 0.5 * ticketB(fold)) - (0.5 + 0.5 * ticketB(lose))) / (0.5 * (ticketB(win) - ticketB(lose)))
    #expect(abs(threshold - transformedThreshold) < 1e-12)
}
