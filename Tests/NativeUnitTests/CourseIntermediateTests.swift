import Foundation
import Testing
@testable import PokerCore

private let intermediateTopics: Set<CourseTopicID> = [.t10, .t16, .t14, .t15, .t17, .t23, .t24, .t25, .t26, .t27, .t32, .t29, .t39, .t34, .t35, .t37]

@Test func intermediateCatalogHasStableUniqueIDsAndAllLearningPurposes() {
    let tasks = FoundationLesson.intermediateExercises
    #expect(tasks.count == 50)
    #expect(Set(tasks.map(\.id)).count == tasks.count)
    #expect(Set(tasks.map(\.topicID)) == intermediateTopics)
    #expect(CourseCatalog.allExerciseIDs.count == 181 + FoundationLesson.finalExercises.count)
    #expect(CourseCatalog.contentVersion == 5)
    #expect(Set(tasks.map(\.id)).isDisjoint(with: Set(FoundationLesson.v2Exercises.map(\.id))))
    for topic in intermediateTopics {
        let group = tasks.filter { $0.topicID == topic }
        #expect(group.count >= 3)
        #expect(Set(group.map(\.purpose)) == Set(FoundationPurpose.allCases))
    }
    // T18 and the M04 starting-hand/chart lessons retain their published providers.
    #expect(CourseCatalog.exercises(for: .t18).count == 6)
    #expect(CourseCatalog.foundations(for: .t18).isEmpty)
    #expect(CourseCatalog.foundations(for: .t21).count == 3)
    #expect(CourseCatalog.foundations(for: .t22).count == 4)
    for task in tasks {
        #expect(FoundationAttempt(exercise: task, response: task.answer.correctResponse).isValid)
        #expect(!task.typicalError.isEmpty && !task.assumptions.isEmpty && !task.method.isEmpty)
        if task.resultKind == .monteCarlo { #expect(task.simulation != nil) }
    }
}

@Test func baselineV2All82ResultsSurviveIntermediateWritesWithIDsDatesGradesAndCompletion() throws {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/course-v2-all82.json")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Intermediate-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let target = directory.appendingPathComponent("history.json")
    let originalBytes = try Data(contentsOf: fixture)
    try originalBytes.write(to: target)
    let history = PracticeHistory(fileURL: target)
    let baseline = try history.loadArchive()
    #expect(try Data(contentsOf: target) == originalBytes)
    let originalCourse = LearningCourseSnapshot(archive: baseline)
    #expect(originalCourse.completedLessons == 8)
    #expect(originalCourse.observations.count == 43)
    #expect(baseline.foundations.count == 39)
    #expect(originalCourse.observations.contains { !$0.isCorrect })
    #expect(baseline.foundations.contains { !$0.isCorrect })
    let oldCatalog = CourseCatalogSnapshot(course: originalCourse, foundations: baseline.foundations)
    #expect(oldCatalog.overallProgress.covered == 82)
    var next = baseline
    let additions = FoundationLesson.intermediateExercises.enumerated().map { index, task in
        FoundationAttempt(exercise: task, response: task.answer.correctResponse,
                          date: Date(timeIntervalSinceReferenceDate: 100_000 + Double(index)))
    }
    next.foundations += additions
    try history.saveArchive(next)
    let restored = try history.loadArchive()
    #expect(restored == next)
    #expect(restored.attempts == baseline.attempts)
    #expect(restored.comparisons == baseline.comparisons)
    #expect(restored.positions == baseline.positions)
    #expect(restored.evCalls == baseline.evCalls)
    #expect(restored.blockers == baseline.blockers)
    #expect(Array(restored.foundations.prefix(39)) == baseline.foundations)
    #expect(LearningCourseSnapshot(archive: restored).completedLessons == 8)
    let snapshot = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: restored), foundations: restored.foundations)
    #expect(snapshot.overallProgress.covered == 132)
    #expect(snapshot.ignoredRecords == 0)
    for topic in intermediateTopics { #expect(snapshot.progress(for: topic).completedAvailableExercises) }
}

@Test func estimationArithmeticUsesIndependentEVRakeAndSamplingUnits() throws {
    #expect(try CourseEstimateMath.rake(pot: 40, rate: 0.05, cap: 3) == 2)
    #expect(try CourseEstimateMath.rake(pot: 100, rate: 0.05, cap: 3) == 3)
    #expect(try CourseEstimateMath.callEV(equity: 0.2, finalPot: 120, call: 20) == 4)
    #expect(abs(try CourseEstimateMath.futureAdjustment(equity: 0.2, winPayment: 30, winChance: 0.5, lossPayment: 30, lossChance: 0.5) + 9) < 1e-10)
    let rakeThreshold = try #require(FoundationLesson.exercise(.init(rawValue: "E.foundation.t15-net-threshold")))
    #expect(rakeThreshold.answer.accepts(.number(100 * 50.0 / 197)))
    #expect(!rakeThreshold.answer.accepts(.number(25)))
    #expect(throws: (any Error).self) { try CourseEstimateMath.rake(pot: 40, rate: 1.01, cap: 3) }
    #expect(throws: (any Error).self) { try CourseEstimateMath.callEV(equity: -.infinity, finalPot: 120, call: 20) }
    #expect(throws: (any Error).self) { try CourseEstimateMath.futureAdjustment(equity: 0.2, winPayment: 30, winChance: 2, lossPayment: 30, lossChance: 0.5) }
}

@Test func recordedMonteCarloReportMatchesFrozenAlgorithmAndIndependentStatistics() throws {
    let report = try CourseMonteCarlo.sample(KnownHandEquityQuestion.examples[0], samples: 20_000, seed: 20_261_021)
    #expect(report == FoundationLesson.recordedEquityReport)
    #expect(report.wins == 18_310 && report.ties == 0 && report.losses == 1_690)
    #expect(report.meanPercent == 91.55)
    let unbiasedVariance = (18_310.0 - 20_000 * 0.9155 * 0.9155) / 19_999
    let independentSE = 100 * sqrt(unbiasedVariance / 20_000)
    #expect(abs(report.standardErrorPP - independentSE) < 1e-10)
    #expect(abs(report.lower95Percent - 91.1645132456207) < 1e-9)
    #expect(abs(report.upper95Percent - 91.9354867543793) < 1e-9)
    let task = try #require(FoundationLesson.exercise(.init(rawValue: "E.foundation.t10.recorded-mean")))
    #expect(task.answer.accepts(.number(91.55)))
    #expect(!task.answer.accepts(.number(100 * 907.0 / 990)))
    #expect(task.simulation == report)
}

@Test func preCancelledCourseSimulationStopsCooperatively() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try CourseMonteCarlo.sample(KnownHandEquityQuestion.examples[0], samples: 20_000, seed: 1)
    }
    do { _ = try await task.value; Issue.record("Cancelled Monte Carlo completed") }
    catch { #expect(error is CancellationError) }
}
