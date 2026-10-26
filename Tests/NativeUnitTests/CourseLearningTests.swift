import Foundation
import Testing
@testable import PokerCore

private let learningEpoch = Date(timeIntervalSinceReferenceDate: 1_000_000)

private func learningSnapshot(_ attempts: [FoundationAttempt]) -> CourseCatalogSnapshot {
    let archive = PracticeArchive(foundations: attempts)
    return CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: archive), foundations: attempts)
}

private func wrongResponse(for exercise: FoundationExercise) -> FoundationResponse {
    switch exercise.answer {
    case .number(let value, let tolerance): .number(value + max(1, tolerance * 2 + 1))
    case .choice(let options, let correct): .choice((correct + 1) % options.count)
    }
}

@Test func learningMetricsDescribeFirstTemplatesAndProjectCriterionWithoutClaimingMastery() throws {
    let tasks = CourseCatalog.foundations(for: .t03)
    let first = try #require(tasks.first)
    let second = try #require(tasks.dropFirst().first)
    let attempts = [
        FoundationAttempt(exercise: first, response: wrongResponse(for: first), id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, date: learningEpoch),
        FoundationAttempt(exercise: first, response: first.answer.correctResponse, id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, date: learningEpoch.addingTimeInterval(10)),
        FoundationAttempt(exercise: second, response: second.answer.correctResponse, id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, date: learningEpoch.addingTimeInterval(20))
    ]
    let metrics = LearningMetrics(progress: learningSnapshot(attempts).progress(for: .t03))

    #expect(metrics.attempts == 3)
    #expect(metrics.distinctTemplates == 2)
    #expect(metrics.firstTemplateAttempts == 2)
    #expect(metrics.firstTemplateCorrect == 1)
    #expect(metrics.firstTemplateAccuracy == 0.5)
    #expect(metrics.lastChecked == learningEpoch.addingTimeInterval(20))
    #expect(metrics.smallSample)
    #expect(metrics.projectCriterionStatus.contains("пока не измерен"))
    #expect(LearningMetrics.projectCriterion.contains("≥80 %"))
}

@Test func wrongAnswerCreatesDeterministicOneDayReviewWithDifferentTask() throws {
    let tasks = CourseCatalog.foundations(for: .t03)
    let first = try #require(tasks.first)
    let wrong = FoundationAttempt(exercise: first, response: wrongResponse(for: first),
                                  id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, date: learningEpoch)
    let snapshot = CourseLearningSnapshot(catalog: learningSnapshot([wrong]), diagnostics: [], now: learningEpoch)
    let review = try #require(snapshot.reviews.first { $0.topicID == .t03 })

    #expect(review.kind == .arithmetic)
    #expect(review.stage == 0)
    #expect(review.dueDate == learningEpoch.addingTimeInterval(86_400))
    #expect(review.sourceAttemptID == wrong.id)
    #expect(review.exerciseID != first.id)
    #expect(snapshot.recommendation(in: CourseCatalog.exerciseIDs(for: .t03)) != first.id)
}

@Test func earlyCorrectDoesNotConsumeReviewAndDueDifferentTaskAdvancesStage() throws {
    let tasks = CourseCatalog.foundations(for: .t03)
    let first = try #require(tasks.first)
    let second = try #require(tasks.dropFirst().first)
    let wrong = FoundationAttempt(exercise: first, response: wrongResponse(for: first),
                                  id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!, date: learningEpoch)
    let early = FoundationAttempt(exercise: second, response: second.answer.correctResponse,
                                  id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, date: learningEpoch.addingTimeInterval(3_600))
    let earlyReview = try #require(CourseLearningSnapshot(catalog: learningSnapshot([wrong, early]), diagnostics: [], now: learningEpoch).reviews.first { $0.topicID == .t03 })
    #expect(earlyReview.stage == 0)
    #expect(earlyReview.dueDate == learningEpoch.addingTimeInterval(86_400))

    let due = FoundationAttempt(exercise: second, response: second.answer.correctResponse,
                                id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!, date: learningEpoch.addingTimeInterval(86_400))
    let advanced = try #require(CourseLearningSnapshot(catalog: learningSnapshot([wrong, due]), diagnostics: [], now: learningEpoch).reviews.first { $0.topicID == .t03 })
    #expect(advanced.stage == 1)
    #expect(advanced.dueDate == due.date.addingTimeInterval(3 * 86_400))
    #expect(advanced.exerciseID != second.id)
}

@Test func laterWrongResetsScheduleAndExplicitDiagnosticWinsOverInference() throws {
    let tasks = CourseCatalog.foundations(for: .t03)
    let first = try #require(tasks.first)
    let second = try #require(tasks.dropFirst().first)
    let initial = FoundationAttempt(exercise: first, response: wrongResponse(for: first),
                                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!, date: learningEpoch)
    let reset = FoundationAttempt(exercise: second, response: wrongResponse(for: second),
                                  id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!, date: learningEpoch.addingTimeInterval(2 * 86_400))
    let catalog = learningSnapshot([initial, reset])
    let explicit = LearningDiagnostic(sourceAttemptID: reset.id, exerciseID: reset.exerciseID, date: reset.date, kind: .modelBoundary)
    let learning = CourseLearningSnapshot(catalog: catalog, diagnostics: [explicit], now: learningEpoch)
    let review = try #require(learning.reviews.first { $0.topicID == .t03 && $0.kind == .modelBoundary })

    #expect(review.sourceAttemptID == reset.id)
    #expect(review.kind == .modelBoundary)
    #expect(review.dueDate == reset.date.addingTimeInterval(86_400))
    #expect(learning.diagnostics.count == 2)
    #expect(learning.reviews.filter { $0.topicID == .t03 }.count == 2)
}

@Test func completedFourthReviewLeavesQueueUntilAnotherWrongAnswer() throws {
    let tasks = CourseCatalog.foundations(for: .t03)
    #expect(tasks.count >= 3)
    let first = tasks[0], second = tasks[1], third = tasks[2]
    let wrong = FoundationAttempt(exercise: first, response: wrongResponse(for: first),
                                  id: UUID(uuidString: "00000000-0000-0000-0000-000000000040")!, date: learningEpoch)
    let a = FoundationAttempt(exercise: second, response: second.answer.correctResponse, id: UUID(), date: learningEpoch.addingTimeInterval(1 * 86_400))
    let b = FoundationAttempt(exercise: third, response: third.answer.correctResponse, id: UUID(), date: a.date.addingTimeInterval(3 * 86_400))
    let c = FoundationAttempt(exercise: first, response: first.answer.correctResponse, id: UUID(), date: b.date.addingTimeInterval(7 * 86_400))
    let d = FoundationAttempt(exercise: second, response: second.answer.correctResponse, id: UUID(), date: c.date.addingTimeInterval(21 * 86_400))
    let completed = CourseLearningSnapshot(catalog: learningSnapshot([wrong, a, b, c, d]), diagnostics: [], now: d.date)
    #expect(completed.reviews.first { $0.topicID == .t03 } == nil)
}

@Test func levelProgressUsesExerciseUnionAndEmptyHistoryRecommendsUnseenTask() {
    let empty = learningSnapshot([])
    let learning = CourseLearningSnapshot(catalog: empty, diagnostics: [], now: learningEpoch)
    #expect(learning.reviews.isEmpty)
    #expect(empty.progress(in: .foundations).exerciseIDs.count > 0)
    #expect(empty.progress(in: .foundations).observations.isEmpty)
    #expect(learning.next(in: CourseCatalog.exerciseIDs(for: .t03)) != nil)
    #expect(learning.next(in: CourseCatalog.allExerciseIDs) == CourseCatalog.exercises(for: .t01).first?.id)
}

@Test func sameTimestampUsesUUIDTieBreakForReplay() throws {
    let task = try #require(CourseCatalog.foundations(for: .t03).first)
    let earlierID = UUID(uuidString: "00000000-0000-0000-0000-000000000050")!
    let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
    let earlier = FoundationAttempt(exercise: task, response: wrongResponse(for: task), id: earlierID, date: learningEpoch)
    let later = FoundationAttempt(exercise: task, response: wrongResponse(for: task), id: laterID, date: learningEpoch)
    let catalog = learningSnapshot([later, earlier])
    let first = CourseLearningSnapshot(catalog: catalog, diagnostics: [], now: learningEpoch)
    let replay = CourseLearningSnapshot(catalog: catalog, diagnostics: [], now: learningEpoch)

    #expect(first.reviews == replay.reviews)
    #expect(first.reviews.first { $0.topicID == .t03 }?.sourceAttemptID == laterID)
}

@Test func sameCategoryWrongResetsWhileOtherCategoryQueueSurvives() throws {
    let tasks = CourseCatalog.foundations(for: .t03)
    let initial = FoundationAttempt(exercise: tasks[0], response: wrongResponse(for: tasks[0]), date: learningEpoch)
    let second = FoundationAttempt(exercise: tasks[1], response: wrongResponse(for: tasks[1]), date: learningEpoch.addingTimeInterval(3600))
    let boundary = FoundationAttempt(exercise: tasks[2], response: wrongResponse(for: tasks[2]), date: learningEpoch.addingTimeInterval(7200))
    let diagnostic = LearningDiagnostic(id: boundary.id, exerciseID: boundary.exerciseID, date: boundary.date, kind: .modelBoundary)
    let model = CourseLearningSnapshot(catalog: learningSnapshot([initial, second, boundary]), diagnostics: [diagnostic], now: boundary.date)
    let queues = model.reviews.filter { $0.topicID == .t03 }
    #expect(queues.count == 2)
    #expect(queues.first { $0.kind == .arithmetic }?.sourceAttemptID == second.id)
    #expect(queues.first { $0.kind == .arithmetic }?.dueDate == second.date.addingTimeInterval(86400))
    #expect(queues.first { $0.kind == .modelBoundary }?.sourceAttemptID == boundary.id)
    #expect(Set(queues.map(\.id)).count == 2)
}

@Test func corruptDiagnosticDateCannotMoveReviewAndTimeZonesDoNotShiftElapsedIntervals() throws {
    let task = try #require(CourseCatalog.foundations(for: .t03).first)
    // A DST transition is irrelevant: the schedule uses exactly 86400 elapsed seconds.
    let date = Date(timeIntervalSince1970: 1_792_883_400)
    let attempt = FoundationAttempt(exercise: task, response: wrongResponse(for: task), date: date)
    let bad = LearningDiagnostic(id: attempt.id, exerciseID: task.id, date: date.addingTimeInterval(-100000), kind: .attention)
    let result = CourseLearningSnapshot(catalog: learningSnapshot([attempt]), diagnostics: [bad], now: date)
    #expect(result.reviews.first?.dueDate.timeIntervalSince(date) == 86400)
    #expect(result.diagnostics.first?.kind == .arithmetic)
}

@Test func allTopicsHaveTypedDiagnosisAndLevelMetricsDeduplicateSharedIDs() throws {
    for id in CourseCatalog.allExerciseIDs { #expect(CourseLearning.inferredKind(for: id) != .unspecified) }
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/course-v4-all181.json")
    let archive = try PracticeHistory(fileURL: fixture).loadArchive()
    let catalog = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: archive), foundations: archive.foundations)
    var union = Set<CatalogExerciseID>()
    for level in CourseLevel.allCases {
        let progress = catalog.progress(in: level)
        union.formUnion(progress.exerciseIDs)
        let expected = catalog.observations.filter { progress.exerciseIDs.contains($0.exerciseID) }
        let metrics = LearningMetrics(progress: progress)
        #expect(metrics.attempts == expected.count)
        #expect(metrics.distinctTemplates == Set(expected.map(\.exerciseID)).count)
        #expect(metrics.lastChecked == expected.map(\.date).max())
    }
    #expect(union == CourseCatalog.allExerciseIDs)
    #expect(LearningMetrics(progress: catalog.overallProgress).distinctTemplates == 181)
}
