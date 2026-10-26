import Foundation
import Testing
@testable import PokerCore

private func lessonPresentationDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("LessonPresentationTests-\(UUID().uuidString)")
}

private func presentedRows<T: Codable>(_ values: [T], offset: Int) throws -> [T] {
    var rows = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(values)) as? [[String: Any]])
    for index in rows.indices {
        rows[index]["id"] = String(format: "00000000-0000-4000-8000-%012d", offset + index + 1)
        rows[index]["date"] = Double(20_000 + offset + index)
    }
    return try JSONDecoder().decode([T].self, from: JSONSerialization.data(withJSONObject: rows))
}

private func completeLessonArchive() throws -> PracticeArchive {
    let numeric = PotOddsQuestion.examples.map { PracticeAttempt(question: $0, answer: $0.correctPercent) }
        + FlushDrawLesson.standard.questions.map { PracticeAttempt(question: $0, answer: $0.correctPercent) }
        + (try KnownHandEquityQuestion.examples.map { question in
            let result = try question.calculate()
            return PracticeAttempt(question: question, result: result, answer: result.equityPercent)
        })
        + (try RangeEquityQuestion.examples.map { question in
            let result = try question.calculate()
            return PracticeAttempt(question: question, result: result, answer: result.equityPercent)
        })
    let comparisons = HandComparisonLesson.questions(seed: 19).map { question in
        HandComparisonAttempt(question: question, answer: question.mode == .winner ? .winner(question.winner) : .bestFive(question.bestFive))
    }
    let positions = try PositionLesson.questions.map { try PositionAttempt(question: $0, answerIndex: $0.correctIndex) }
    let evCalls = try EVCallQuestion.examples.map { try EVCallAttempt(question: $0, decision: $0.result.accepts(.call) ? .call : .fold) }
    let blockers = try BlockerQuestion.examples.map { question in
        try BlockerAttempt(questionID: question.id, answerIndex: try #require(question.correctIndex))
    }
    return PracticeArchive(
        attempts: try presentedRows(numeric, offset: 0),
        comparisons: try presentedRows(comparisons, offset: 100),
        positions: try presentedRows(positions, offset: 200),
        evCalls: try presentedRows(evCalls, offset: 300),
        blockers: try presentedRows(blockers, offset: 400)
    )
}

@Test func lessonGuidesCoverEveryPublishedLessonWithReadableSteps() {
    for lesson in CourseLessonID.allCases {
        let guide = LessonGuide.guide(for: lesson)
        #expect(!guide.goal.isEmpty)
        #expect(!guide.term.isEmpty && !guide.definition.isEmpty && !guide.example.isEmpty)
        #expect(!guide.when.isEmpty && !guide.assumptions.isEmpty)
        #expect(guide.steps.count >= 3)
        #expect(guide.steps.allSatisfy { !$0.isEmpty })
    }
    #expect(CourseLessonID.allCases.count == 8)
}

@Test func catalogExercisesResolveToTheirTypedLegacyProviders() {
    let comparisonKeys = Set(HandComparisonLesson.questions(seed: 19).compactMap { CourseLessonID.comparisonKey($0.id) })
    let providerKeys: [CourseLessonID: Set<String>] = [
        .combinations: comparisonKeys,
        .outs: Set(FlushDrawLesson.standard.questions.map(\.id)),
        .potOdds: Set(PotOddsQuestion.examples.map(\.id)),
        .knownEquity: Set(KnownHandEquityQuestion.examples.map(\.id)),
        .positions: Set(PositionLesson.questions.map(\.id)),
        .rangeEquity: Set(RangeEquityQuestion.examples.map(\.id)),
        .evCall: Set(EVCallQuestion.examples.map(\.id)),
        .blockers: Set(BlockerQuestion.examples.map(\.id)),
    ]

    #expect(CourseCatalog.exercises.count == 43)
    for exercise in CourseCatalog.exercises {
        #expect(providerKeys[exercise.lesson]?.contains(exercise.legacyKey) == true)
        #expect(CourseCatalog.exercise(lesson: exercise.lesson, legacyKey: exercise.legacyKey)?.id == exercise.id)
    }
}

@Test func resultKindsLabelMethodsWithoutInventingSamplesOrTables() {
    let kinds = Set(CourseCatalog.exercises.map(\.resultKind))
    #expect(!kinds.contains(.monteCarlo))
    #expect(!kinds.contains(.verifiedTable))
    #expect(CourseCatalog.exercises.filter { $0.lesson == .positions }.allSatisfy { $0.resultKind == .definitions })
    #expect(CourseCatalog.exercises.filter { $0.lesson == .rangeEquity || $0.lesson == .evCall }.allSatisfy { $0.resultKind == .conditionalModel })
    #expect(CourseCatalog.exercises.filter { $0.lesson == .blockers && ["blockers-range-v1", "blockers-weights-v1", "blockers-bluffs-v1"].contains($0.legacyKey) }.allSatisfy { $0.resultKind == .conditionalModel })
    #expect(CourseCatalog.exercises.filter { $0.lesson == .potOdds }.allSatisfy { $0.resultKind == .exact })
}

@Test func nextExerciseStaysWithinTopicAndEndsAtLastTask() throws {
    let tasks = CourseCatalog.exercises(for: .t11)
    #expect(tasks.map(\.id) == [
        CatalogExerciseID(rawValue: "E.pot.100.50"), CatalogExerciseID(rawValue: "E.pot.120.120"), CatalogExerciseID(rawValue: "E.pot.200.50"),
        CatalogExerciseID(rawValue: "E.ev.positive"), CatalogExerciseID(rawValue: "E.ev.negative"), CatalogExerciseID(rawValue: "E.ev.zero"),
    ])
    for pair in zip(tasks, tasks.dropFirst()) {
        #expect(CourseCatalog.nextExercise(after: pair.0.id, in: .t11)?.id == pair.1.id)
        #expect(CourseCatalog.nextExercise(after: pair.0.id, in: .t11)?.topicIDs.contains(.t11) == true)
    }
    #expect(CourseCatalog.nextExercise(after: try #require(tasks.last).id, in: .t11) == nil)
    #expect(CourseCatalog.nextExercise(after: CatalogExerciseID(rawValue: "E.hand.highcard"), in: .t11) == nil)
}

@Test func catalogProgressPreservesHistoricalRecordsAndDeduplicatesSharedExercises() throws {
    let directory = lessonPresentationDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let archive = try completeLessonArchive()
    let blocker = try #require(archive.blockers.first)
    let pot = try #require(archive.attempts.first { $0.questionID == "pot-100-bet-50-v1" })
    let history = PracticeHistory(fileURL: directory.appendingPathComponent("practice.json"))

    let before = LearningCourseSnapshot(archive: archive)
    #expect(before.completedLessons == 8)
    try history.saveArchive(archive)
    let restored = try history.loadArchive()
    #expect(restored.attempts == archive.attempts && restored.comparisons == archive.comparisons)
    #expect(restored.positions == archive.positions && restored.evCalls == archive.evCalls && restored.blockers == archive.blockers)
    #expect(restored.foundations == archive.foundations)
    #expect(restored.diagnostics == CourseLearning.inferredDiagnostics(catalog: CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: archive), foundations: archive.foundations)))
    #expect(restored.blockers.first?.id == blocker.id && restored.blockers.first?.date == blocker.date)
    #expect(restored.attempts.first { $0.questionID == pot.questionID }?.id == pot.id)
    #expect(restored.attempts.first { $0.questionID == pot.questionID }?.date == pot.date)

    let catalog = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: restored))
    #expect(catalog.ignoredRecords == 0)
    #expect(catalog.observations.count == 43)
    #expect(Set(catalog.observations.map(\.id)).count == 43)
    #expect(catalog.overallProgress.covered == 43)
    #expect(catalog.overallProgress.latestCorrect == 43)
    #expect(!catalog.overallProgress.completedAvailableExercises) // New curriculum tasks remain available alongside the complete legacy sets.
    #expect(catalog.progress(for: .t60).exerciseIDs.count == 3)
    #expect(catalog.progress(for: .t60).covered == 0)
    #expect(!catalog.progress(for: .t60).completedAvailableExercises)
    #expect(catalog.progress(for: .t06).covered == 3)
    #expect(catalog.progress(for: .t18).covered == 6)
    #expect(catalog.progress(for: .t11).covered == 6)
    #expect(catalog.progress(for: .t02).covered == 9)
    #expect(catalog.progress(for: .t21).covered == 3)
    #expect(catalog.progress(in: .m01).covered == 21)
    #expect(catalog.progress(in: .m02).covered == 5)
    #expect(catalog.progress(in: .m03).covered == 11)
    #expect(catalog.progress(in: .m08).covered == 6)
    #expect(catalog.observations.filter { $0.id == blocker.id }.count == 1)
}
