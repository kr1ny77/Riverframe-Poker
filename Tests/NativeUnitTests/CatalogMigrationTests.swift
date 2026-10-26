import Foundation
import Testing
@testable import PokerCore

private func catalogTestDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("CatalogMigrationTests-\(UUID().uuidString)")
}

private func stableRows<T: Codable>(_ values: [T], offset: Int) throws -> [T] {
    var rows = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(values)) as? [[String: Any]])
    for index in rows.indices {
        rows[index]["id"] = String(format: "00000000-0000-4000-8000-%012d", offset + index + 1)
        rows[index]["date"] = Double(10_000 + offset + index)
    }
    return try JSONDecoder().decode([T].self, from: JSONSerialization.data(withJSONObject: rows))
}

private func catalogFixture() throws -> PracticeArchive {
    let numeric = PotOddsQuestion.examples.enumerated().map { index, question in
        PracticeAttempt(question: question, answer: index == 0 ? 0 : question.correctPercent)
    }
        + FlushDrawLesson.standard.questions.map { PracticeAttempt(question: $0, answer: $0.correctPercent) }
        + (try KnownHandEquityQuestion.examples.map { question in
            let result = try question.calculate()
            return PracticeAttempt(question: question, result: result, answer: result.equityPercent)
        })
        + (try RangeEquityQuestion.examples.map { question in
            let result = try question.calculate()
            return PracticeAttempt(question: question, result: result, answer: result.equityPercent)
        })
    let comparisons = HandComparisonLesson.questions(seed: 73).map { question in
        HandComparisonAttempt(question: question, answer: question.mode == .winner ? .winner(question.winner) : .bestFive(question.bestFive))
    }
    let positions = try PositionLesson.questions.enumerated().map { index, question in
        let answerIndex = index == 0 ? (question.correctIndex + 1) % question.choices.count : question.correctIndex
        return try PositionAttempt(question: question, answerIndex: answerIndex)
    }
    let evCalls = try EVCallQuestion.examples.enumerated().map { index, question in
        try EVCallAttempt(question: question, decision: index == 1 ? .call : (question.result.accepts(.call) ? .call : .fold))
    }
    let blockers = try BlockerQuestion.examples.enumerated().map { index, question in
        let correct = try #require(question.correctIndex)
        return try BlockerAttempt(questionID: question.id, answerIndex: index == 0 ? (correct + 1) % question.choices.count : correct)
    }
    return PracticeArchive(
        attempts: try stableRows(numeric, offset: 0),
        comparisons: try stableRows(comparisons, offset: 100),
        positions: try stableRows(positions, offset: 200),
        evCalls: try stableRows(evCalls, offset: 300),
        blockers: try stableRows(blockers, offset: 400)
    )
}

private func envelopeData(version: Int, archive: PracticeArchive) throws -> Data {
    var envelope: [String: Any] = [
        "version": version,
        "attempts": try JSONSerialization.jsonObject(with: JSONEncoder().encode(archive.attempts)),
    ]
    if version >= 2 { envelope["comparisons"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(archive.comparisons)) }
    if version >= 3 { envelope["positions"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(archive.positions)) }
    if version >= 4 { envelope["evCalls"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(archive.evCalls)) }
    if version >= 5 { envelope["blockers"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(archive.blockers)) }
    return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
}

@Test(arguments: [1, 2, 3, 4, 5])
func catalogReadsEverySupportedSchemaWithoutMutatingSourceBytes(version: Int) throws {
    let directory = catalogTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let archive = try catalogFixture()
    let path = directory.appendingPathComponent("history.json")
    let source = try envelopeData(version: version, archive: archive)
    try source.write(to: path)

    let loaded = try PracticeHistory(fileURL: path).loadArchive()
    #expect(try Data(contentsOf: path) == source)
    #expect(loaded.attempts == archive.attempts)
    #expect(loaded.comparisons == (version >= 2 ? archive.comparisons : []))
    #expect(loaded.positions == (version >= 3 ? archive.positions : []))
    #expect(loaded.evCalls == (version >= 4 ? archive.evCalls : []))
    #expect(loaded.blockers == (version >= 5 ? archive.blockers : []))

    let course = LearningCourseSnapshot(archive: loaded)
    let catalog = CourseCatalogSnapshot(course: course)
    #expect(course.ignoredRecords == 0 && catalog.ignoredRecords == 0)
    #expect(catalog.observations.count == course.observations.count)
    #expect(Set(catalog.observations.map(\.id)).count == catalog.observations.count)

    try PracticeHistory(fileURL: path).saveArchive(loaded)
    let normalized = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    #expect(normalized["version"] as? Int == 7)
    let restored = try PracticeHistory(fileURL: path).loadArchive()
    let restoredCourse = LearningCourseSnapshot(archive: restored)
    #expect(restored == loaded)
    #expect(course.observations.count == restoredCourse.observations.count)
    #expect(zip(course.observations, restoredCourse.observations).allSatisfy { source, restored in
        source.id == restored.id && source.date == restored.date && source.key == restored.key && source.isCorrect == restored.isCorrect
    })
    let availableLessons = CourseLessonID.allCases.filter { lesson in
        switch lesson {
        case .combinations: version >= 2
        case .positions: version >= 3
        case .evCall: version >= 4
        case .blockers: version >= 5
        case .outs, .potOdds, .knownEquity, .rangeEquity: true
        }
    }
    #expect(availableLessons.allSatisfy { course.progress($0).completed && restoredCourse.progress($0).completed })
    let availableT11 = CourseCatalog.exercises(for: .t11).filter { version >= 4 || $0.lesson == .potOdds }
    #expect(availableT11.allSatisfy { exercise in catalog.observations.contains { $0.exerciseID == exercise.id } })
    if version >= 3 {
        #expect(CourseCatalog.exercises(for: .t02).allSatisfy { exercise in catalog.observations.contains { $0.exerciseID == exercise.id } })
        #expect(CourseCatalog.exercises(for: .t21).allSatisfy { exercise in catalog.observations.contains { $0.exerciseID == exercise.id } })
    }
    if version >= 5 {
        #expect(CourseLessonID.allCases.allSatisfy { course.progress($0).completed && restoredCourse.progress($0).completed })
        #expect(catalog.progress(for: .t06).covered == 3 && !catalog.progress(for: .t06).completedAvailableExercises)
        #expect(catalog.progress(for: .t18).completedAvailableExercises)
    }
}

@Test func catalogSchemaFiveRoundTripPreservesAllStoredFieldsAndCompletion() throws {
    let directory = catalogTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("history.json")
    let archive = try catalogFixture()
    let history = PracticeHistory(fileURL: path)
    try history.saveArchive(archive)
    let restored = try history.loadArchive()
    #expect(restored.attempts == archive.attempts && restored.comparisons == archive.comparisons
        && restored.positions == archive.positions && restored.evCalls == archive.evCalls
        && restored.blockers == archive.blockers && restored.foundations == archive.foundations)
    #expect(restored.diagnostics == CourseLearning.inferredDiagnostics(catalog: CourseCatalogSnapshot(
        course: LearningCourseSnapshot(archive: archive), foundations: archive.foundations)))

    let source = LearningCourseSnapshot(archive: archive)
    let restoredCourse = LearningCourseSnapshot(archive: restored)
    #expect(source.observations.count == restoredCourse.observations.count)
    #expect(zip(source.observations, restoredCourse.observations).allSatisfy { source, restored in
        source.id == restored.id && source.date == restored.date && source.key == restored.key && source.isCorrect == restored.isCorrect
    })
    #expect(CourseLessonID.allCases.allSatisfy { restoredCourse.progress($0).completed })
    #expect(restoredCourse.observations.count == 43)
    #expect(restoredCourse.observations.contains(where: { !$0.isCorrect }))

    let catalog = CourseCatalogSnapshot(course: restoredCourse)
    #expect(catalog.observations.count == 43)
    #expect(catalog.observations.allSatisfy { $0.contentVersion == 1 })
    #expect(catalog.observations.allSatisfy { observation in
        CourseCatalog.exercises.contains { exercise in exercise.id == observation.exerciseID }
    })
    #expect(catalog.progress(for: .t11).completedAvailableExercises)
    #expect(catalog.progress(for: .t02).completedAvailableExercises)
    #expect(catalog.progress(for: .t21).covered == 3 && !catalog.progress(for: .t21).completedAvailableExercises)
    #expect(catalog.progress(for: .t06).covered == 3 && !catalog.progress(for: .t06).completedAvailableExercises)
    #expect(catalog.progress(for: .t18).completedAvailableExercises)

    let blockerIDs = Set(catalog.progress(for: .t06).observations.map(\.id))
    #expect(blockerIDs == Set(catalog.progress(for: .t18).observations.map(\.id)).intersection(blockerIDs))
    #expect(Set(catalog.observations.map(\.id)).count == 43)
}

@Test func catalogIDsReferencesAndLegacyOverlapMappingsAreStable() {
    #expect(CourseCatalog.contentVersion == 5)
    #expect(Set(CourseTopicID.allCases.map(\.rawValue)).count == 60)
    #expect(Set(CourseModuleID.allCases.map(\.rawValue)).count == 18)
    #expect(Set(CourseLevel.allCases).count == 4)
    #expect(Set(CourseCatalog.modules.map(\.id)).count == CourseCatalog.modules.count)
    #expect(Set(CourseCatalog.topics.map(\.id)).count == CourseCatalog.topics.count)
    #expect(Set(CourseCatalog.exercises.map(\.id)).count == CourseCatalog.exercises.count)
    #expect(CourseCatalog.exercises.count == 43)
    #expect(CourseCatalog.topics.allSatisfy { topic in
        CourseCatalog.modules.contains { $0.id == topic.moduleID }
            && topic.prerequisites.allSatisfy { prerequisite in CourseCatalog.topics.contains { $0.id == prerequisite } }
    })
    #expect(CourseCatalog.exercises.allSatisfy { exercise in
        !exercise.topicIDs.isEmpty
            && exercise.topicIDs.allSatisfy { topic in CourseCatalog.topics.contains { $0.id == topic } }
            && CourseCatalog.exercise(lesson: exercise.lesson, legacyKey: exercise.legacyKey)?.id == exercise.id
    })
    #expect(CourseLessonID.allCases.allSatisfy { lesson in
        Set(CourseCatalog.exercises.filter { $0.lesson == lesson }.map(\.legacyKey)) == lesson.requiredKeys
    })
    #expect(CourseCatalog.exercise(lesson: .potOdds, legacyKey: "pot-100-bet-50-v1")?.id == CatalogExerciseID(rawValue: "E.pot.100.50"))

    let t11 = CourseCatalog.exercises(for: .t11)
    #expect(Set(t11.map(\.lesson)) == [.potOdds, .evCall])
    let positions = CourseCatalog.exercises.filter { $0.lesson == .positions }
    #expect(CourseCatalog.exercises(for: .t02).contains(where: { topicExercise in positions.contains { positionExercise in positionExercise.id == topicExercise.id } }))
    #expect(CourseCatalog.exercises(for: .t21).contains(where: { topicExercise in positions.contains { positionExercise in positionExercise.id == topicExercise.id } }))
    let blockers = CourseCatalog.exercises.filter { $0.lesson == .blockers }
    #expect(CourseCatalog.exercises(for: .t06).filter { topicExercise in blockers.contains { blockerExercise in blockerExercise.id == topicExercise.id } }.count == 3)
    #expect(CourseCatalog.exercises(for: .t18).filter { topicExercise in blockers.contains { blockerExercise in blockerExercise.id == topicExercise.id } }.count == 6)
}

@Test func catalogRejectsInvalidOrCorruptArchivesWithoutChangingTheirBytes() throws {
    let directory = catalogTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent("history.json")
    let history = PracticeHistory(fileURL: path)
    for data in [Data("{\"version\":6,\"attempts\":[]}".utf8), Data("{corrupt".utf8)] {
        try data.write(to: path)
        #expect(throws: (any Error).self) { try history.loadArchive() }
        #expect(try Data(contentsOf: path) == data)
    }
}

@Test func catalogAtomicWriteFailureLeavesTargetDirectoryUntouched() throws {
    let directory = catalogTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let target = directory.appendingPathComponent("target")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    let marker = target.appendingPathComponent("marker.txt")
    try Data("marker".utf8).write(to: marker)
    let archive = try catalogFixture()
    let before = try FileManager.default.contentsOfDirectory(atPath: target.path).sorted()
    #expect(throws: (any Error).self) { try PracticeHistory(fileURL: target).saveArchive(archive) }
    #expect(try Data(contentsOf: marker) == Data("marker".utf8))
    #expect(try FileManager.default.contentsOfDirectory(atPath: target.path).sorted() == before)
}


@Test func catalogPreservesUnmappedLegacyAttemptsWithoutCountingThemAsCoverage() throws {
    let directory = catalogTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("history.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let known = PotOddsQuestion.examples.map { PracticeAttempt(question: $0, answer: $0.correctPercent) }
    let unknown = PracticeAttempt(questionID: "historical-unknown-v1", answer: 12.5, expectedPercent: 25)
    let archive = PracticeArchive(attempts: known + [unknown])
    let original = try envelopeData(version: 1, archive: archive)
    try original.write(to: path)
    let history = PracticeHistory(fileURL: path)
    let loaded = try history.loadArchive()
    let course = LearningCourseSnapshot(archive: loaded)
    let catalog = CourseCatalogSnapshot(course: course)
    #expect(course.progress(.potOdds).completed)
    #expect(catalog.ignoredRecords == 1 && catalog.observations.count == 3)
    #expect(catalog.progress(for: .t11).covered == 3)
    #expect(try Data(contentsOf: path) == original)
    try history.saveArchive(loaded)
    #expect(try history.loadArchive().attempts == known + [unknown])
}
