import Foundation
import Testing
@testable import PokerCore

private func diagnosticsDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("LearningDiagnosticsArchiveTests-\(UUID().uuidString)")
}

private func wrongPotOddsAttempt(id: UUID = UUID(), date: Date = Date(timeIntervalSinceReferenceDate: 123_456)) throws -> PracticeAttempt {
    let question = PotOddsQuestion.examples[0]
    var row = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(PracticeAttempt(question: question, answer: 0))) as? [String: Any])
    row["id"] = id.uuidString
    row["date"] = date.timeIntervalSinceReferenceDate
    return try! JSONDecoder().decode(PracticeAttempt.self, from: JSONSerialization.data(withJSONObject: row))
}

private func diagnosticEnvelope(version: Int, attempt: PracticeAttempt) throws -> Data {
    var document: [String: Any] = [
        "version": version,
        "attempts": try JSONSerialization.jsonObject(with: JSONEncoder().encode([attempt])),
    ]
    if version >= 2 { document["comparisons"] = [] }
    if version >= 3 { document["positions"] = [] }
    if version >= 4 { document["evCalls"] = [] }
    if version >= 5 { document["blockers"] = [] }
    if version >= 6 { document["foundations"] = [] }
    if version >= 7 { document["diagnostics"] = [] }
    return try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
}

@Test(arguments: [1, 2, 3, 4, 5, 6])
func legacySchemasProjectStableWrongAnswerDiagnosticsWithoutWriting(version: Int) throws {
    let directory = diagnosticsDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent("history.json")
    let attempt = try wrongPotOddsAttempt(id: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!)
    let source = try diagnosticEnvelope(version: version, attempt: attempt)
    try source.write(to: path)

    let restored = try PracticeHistory(fileURL: path).loadArchive()
    #expect(restored.attempts == [attempt])
    #expect(restored.diagnostics == [
        LearningDiagnostic(sourceAttemptID: attempt.id, exerciseID: CatalogExerciseID(rawValue: "E.pot.100.50"),
                           date: attempt.date, kind: .arithmetic),
    ])
    #expect(try Data(contentsOf: path) == source)
}

@Test func schemaSevenRoundTripPreservesExplicitKindAndAllSourceFields() throws {
    let directory = diagnosticsDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("history.json")
    let attempt = try wrongPotOddsAttempt(id: UUID(uuidString: "00000000-0000-4000-8000-000000000702")!)
    let diagnostic = LearningDiagnostic(sourceAttemptID: attempt.id, exerciseID: CatalogExerciseID(rawValue: "E.pot.100.50"),
                                        date: attempt.date, kind: .attention)
    let archive = PracticeArchive(attempts: [attempt], diagnostics: [diagnostic])
    let history = PracticeHistory(fileURL: path)

    try history.saveArchive(archive)
    let restored = try history.loadArchive()
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    #expect(object["version"] as? Int == 7)
    #expect(restored.attempts == [attempt])
    #expect(restored.diagnostics == [diagnostic])
}

@Test func schemaSevenRejectsDuplicateOrMismatchedDiagnosticsWithoutChangingBytes() throws {
    let directory = diagnosticsDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent("history.json")
    let attempt = try wrongPotOddsAttempt(id: UUID(uuidString: "00000000-0000-4000-8000-000000000703")!)
    let correct = LearningDiagnostic(sourceAttemptID: attempt.id, exerciseID: CatalogExerciseID(rawValue: "E.pot.100.50"),
                                     date: attempt.date, kind: .unspecified)
    let history = PracticeHistory(fileURL: path)
    try history.saveArchive(PracticeArchive(attempts: [attempt], diagnostics: [correct]))
    let document = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    let rows = try #require(document["diagnostics"] as? [[String: Any]])

    var duplicate = document
    duplicate["diagnostics"] = rows + rows
    var mismatch = document
    var wrongRows = rows
    wrongRows[0]["exerciseID"] = "E.pot.120.120"
    mismatch["diagnostics"] = wrongRows

    for invalid in [duplicate, mismatch] {
        let bytes = try JSONSerialization.data(withJSONObject: invalid, options: [.sortedKeys])
        try bytes.write(to: path)
        #expect(throws: (any Error).self) { try history.loadArchive() }
        #expect(try Data(contentsOf: path) == bytes)
    }
}
