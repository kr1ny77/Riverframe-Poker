import Foundation
import Testing
@testable import PokerCore

private func foundationArchiveDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("FoundationArchiveTests-\(UUID().uuidString)")
}

private func wrongFoundationResponse(for answer: FoundationAnswer) -> FoundationResponse {
    switch answer {
    case .number(let value, let tolerance):
        return .number(value + max(1, tolerance + 1))
    case .choice(let options, let correct):
        return .choice(options.indices.first { $0 != correct }!)
    }
}

private func foundationArchiveAttempts() -> [FoundationAttempt] {
    FoundationLesson.v2Exercises.enumerated().map { index, exercise in
        let response = index.isMultiple(of: 2) ? exercise.answer.correctResponse : wrongFoundationResponse(for: exercise.answer)
        let identifier = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!
        return FoundationAttempt(exercise: exercise, response: response, id: identifier,
                                 date: Date(timeIntervalSinceReferenceDate: 50_000 + Double(index)))
    }
}

private func legacyArchiveFixture() throws -> PracticeArchive {
    let numeric = PracticeAttempt(question: PotOddsQuestion.examples[0], answer: 25)
    let comparisonQuestion = HandComparisonLesson.questions(seed: 31)[0]
    let comparisonAnswer: HandComparisonAnswer = comparisonQuestion.mode == .winner
        ? .winner(comparisonQuestion.winner)
        : .bestFive(comparisonQuestion.firstRank.bestFive)
    let comparison = HandComparisonAttempt(question: comparisonQuestion, answer: comparisonAnswer)
    let position = try PositionAttempt(question: PositionLesson.questions[0], answerIndex: PositionLesson.questions[0].correctIndex)
    let evCall = try EVCallAttempt(question: EVCallQuestion.examples[0], decision: .call)
    let blocker = try BlockerAttempt(questionID: BlockerQuestion.examples[0].id, answerIndex: 1)
    return PracticeArchive(attempts: [numeric], comparisons: [comparison], positions: [position], evCalls: [evCall], blockers: [blocker])
}

private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
}

private func legacyEnvelope(version: Int, archive: PracticeArchive) throws -> Data {
    var document: [String: Any] = ["version": version, "attempts": try jsonObject(archive.attempts)]
    if version >= 2 { document["comparisons"] = try jsonObject(archive.comparisons) }
    if version >= 3 { document["positions"] = try jsonObject(archive.positions) }
    if version >= 4 { document["evCalls"] = try jsonObject(archive.evCalls) }
    if version >= 5 { document["blockers"] = try jsonObject(archive.blockers) }
    return try JSONSerialization.data(withJSONObject: document)
}

private func archiveThrough(version: Int, fixture: PracticeArchive) -> PracticeArchive {
    PracticeArchive(
        attempts: fixture.attempts,
        comparisons: version >= 2 ? fixture.comparisons : [],
        positions: version >= 3 ? fixture.positions : [],
        evCalls: version >= 4 ? fixture.evCalls : [],
        blockers: version >= 5 ? fixture.blockers : []
    )
}

@Test func archiveVersionsOneThroughFiveMigrateToSixWithoutChangingLegacyRecords() throws {
    let directory = foundationArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent("history.json")
    let fixture = try legacyArchiveFixture()
    let history = PracticeHistory(fileURL: path)

    for version in 1...5 {
        let bytes = try legacyEnvelope(version: version, archive: fixture)
        try bytes.write(to: path)
        let loaded = try history.loadArchive()
        let expected = archiveThrough(version: version, fixture: fixture)
        #expect(loaded == expected)
        #expect(loaded.foundations.isEmpty)
        #expect(try Data(contentsOf: path) == bytes)

        try history.saveArchive(loaded)
        let migrated = try history.loadArchive()
        #expect(migrated == expected)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        #expect(object["version"] as? Int == 7)
        #expect(migrated.attempts.map(\.id) == expected.attempts.map(\.id))
        #expect(migrated.attempts.map(\.date) == expected.attempts.map(\.date))
        #expect(migrated.attempts.map(\.answer) == expected.attempts.map(\.answer))
        #expect(migrated.comparisons.map(\.id) == expected.comparisons.map(\.id))
        #expect(migrated.positions.map(\.date) == expected.positions.map(\.date))
        #expect(migrated.evCalls.map(\.isCorrect) == expected.evCalls.map(\.isCorrect))
        #expect(migrated.blockers.map(\.answerIndex) == expected.blockers.map(\.answerIndex))
    }
}

@Test func versionSixRoundTripPreservesAllFoundationResponsesAndLegacySaveKeepsThem() throws {
    let directory = foundationArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("history.json")
    let history = PracticeHistory(fileURL: path)
    let foundations = foundationArchiveAttempts()
    #expect(foundations.count == 39)
    #expect(Set(foundations.map(\.id)).count == 39)
    #expect(foundations.contains(where: \.isCorrect) && foundations.contains(where: { !$0.isCorrect }))

    let numeric = PracticeAttempt(question: PotOddsQuestion.examples[0], answer: 25)
    let archive = PracticeArchive(attempts: [numeric], foundations: foundations)
    try history.saveArchive(archive)
    let restored = try history.loadArchive()
    #expect(restored.attempts == archive.attempts && restored.foundations == foundations)
    let catalog = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: archive), foundations: foundations)
    #expect(restored.diagnostics == CourseLearning.inferredDiagnostics(catalog: catalog))

    try history.save([])
    let afterLegacyNumericSave = try history.loadArchive()
    #expect(afterLegacyNumericSave.attempts.isEmpty)
    #expect(afterLegacyNumericSave.foundations == foundations)
    #expect(afterLegacyNumericSave.foundations.map(\.id) == foundations.map(\.id))
    #expect(afterLegacyNumericSave.foundations.map(\.date) == foundations.map(\.date))
    #expect(afterLegacyNumericSave.foundations.map(\.response) == foundations.map(\.response))
    #expect(afterLegacyNumericSave.foundations.map(\.isCorrect) == foundations.map(\.isCorrect))
    #expect(afterLegacyNumericSave.diagnostics == CourseLearning.inferredDiagnostics(catalog: CourseCatalogSnapshot(
        course: LearningCourseSnapshot(archive: afterLegacyNumericSave), foundations: foundations)))
}

@Test func archiveRejectsForgedFoundationGradeDuplicatesCorruptionAndUnsupportedVersionWithoutWriting() throws {
    let directory = foundationArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("history.json")
    let history = PracticeHistory(fileURL: path)
    let numeric = PracticeAttempt(question: PotOddsQuestion.examples[0], answer: 25)
    let foundation = foundationArchiveAttempts()[0]
    let choiceExercise = try #require(FoundationLesson.v2Exercises.first {
        if case .choice = $0.answer { return true }
        return false
    })
    let choiceFoundation = FoundationAttempt(exercise: choiceExercise, response: choiceExercise.answer.correctResponse,
                                             id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
                                             date: Date(timeIntervalSinceReferenceDate: 50_101))
    try history.saveArchive(PracticeArchive(attempts: [numeric], foundations: [foundation, choiceFoundation]))
    let good = try Data(contentsOf: path)
    let object = try #require(JSONSerialization.jsonObject(with: good) as? [String: Any])

    var forgedGrade = object
    var foundationRows = try #require(forgedGrade["foundations"] as? [[String: Any]])
    foundationRows[0]["isCorrect"] = !foundation.isCorrect
    forgedGrade["foundations"] = foundationRows

    var forgedExpected = object
    foundationRows = try #require(forgedExpected["foundations"] as? [[String: Any]])
    foundationRows[0]["expected"] = try jsonObject(FoundationResponse.number(999))
    forgedExpected["foundations"] = foundationRows

    var outOfRangeChoice = object
    foundationRows = try #require(outOfRangeChoice["foundations"] as? [[String: Any]])
    foundationRows[1]["response"] = try jsonObject(FoundationResponse.choice(99))
    foundationRows[1]["isCorrect"] = false
    outOfRangeChoice["foundations"] = foundationRows

    var duplicateIdentity = object
    foundationRows = try #require(duplicateIdentity["foundations"] as? [[String: Any]])
    foundationRows[0]["id"] = numeric.id.uuidString
    duplicateIdentity["foundations"] = foundationRows

    var unsupportedVersion = object
    unsupportedVersion["version"] = 8

    let invalidDocuments = [
        try JSONSerialization.data(withJSONObject: forgedGrade),
        try JSONSerialization.data(withJSONObject: forgedExpected),
        try JSONSerialization.data(withJSONObject: outOfRangeChoice),
        try JSONSerialization.data(withJSONObject: duplicateIdentity),
        Data("{corrupt".utf8),
        try JSONSerialization.data(withJSONObject: unsupportedVersion),
    ]
    for bytes in invalidDocuments {
        try bytes.write(to: path)
        #expect(throws: (any Error).self) { try history.loadArchive() }
        #expect(try Data(contentsOf: path) == bytes)
    }
}

@Test func unknownFoundationRevisionRoundTripsAndIsIgnoredByCurrentCatalog() throws {
    let directory = foundationArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("history.json")
    let history = PracticeHistory(fileURL: path)
    let current = foundationArchiveAttempts()[0]
    try history.saveArchive(PracticeArchive(foundations: [current]))
    var document = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    var records = try #require(document["foundations"] as? [[String: Any]])
    records[0]["contentVersion"] = current.contentVersion + 1
    document["foundations"] = records
    let bytes = try JSONSerialization.data(withJSONObject: document)
    try bytes.write(to: path)

    let restored = try history.loadArchive()
    #expect(restored.foundations.count == 1)
    #expect(restored.foundations[0].contentVersion == current.contentVersion + 1)
    #expect(try Data(contentsOf: path) == bytes)
    let catalog = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: restored), foundations: restored.foundations)
    #expect(catalog.observations.isEmpty)
    #expect(catalog.ignoredRecords == 1)
}
