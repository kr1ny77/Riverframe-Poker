import Foundation
@testable import PokerCore

final class PracticeTests: CoreCheckCase {
    func testPotOddsUsesFinalPotIncludingCall() {
        let question = PotOddsQuestion.examples[0]
        assertEqual(question.callAmount, 50)
        assertEqual(question.finalPot, 200)
        assertEqual(question.correctPercent, 25, accuracy: 0.000001)
        assertEqual(question.explanation.count, 5)
        assertTrue(question.explanation[3].contains("50 / 200"))
        assertEqual(PotOddsQuestion.examples[1].correctPercent, 100.0/3, accuracy: 0.000001)
        assertEqual(PotOddsQuestion.examples[2].correctPercent, 100.0/6, accuracy: 0.000001)
    }

    func testAnswerToleranceIncludesBoundaryAndRejectsOutside() {
        let question = PotOddsQuestion.examples[0]
        assertTrue(PracticeAttempt(question: question, answer: 25).isCorrect)
        assertTrue(PracticeAttempt(question: question, answer: 24.5).isCorrect)
        assertTrue(PracticeAttempt(question: question, answer: 25.5).isCorrect)
        assertFalse(PracticeAttempt(question: question, answer: 24.49).isCorrect)
        assertFalse(PracticeAttempt(question: question, answer: 25.51).isCorrect)
        assertFalse(PracticeAttempt(question: question, answer: 0).isCorrect)
        assertFalse(PracticeAttempt(question: question, answer: 100).isCorrect)
    }

    private func temporaryHistory() throws -> PracticeHistory {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PokerCoreTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return PracticeHistory(fileURL: directory.appendingPathComponent("nested/history.json"))
    }

    func testHistoryMissingFileAndAtomicRoundTripReplacement() throws {
        let history = try temporaryHistory()
        assertEqual(try history.load(), [])
        let first = PracticeAttempt(question: PotOddsQuestion.examples[0], answer: 25)
        try history.save([first])
        assertEqual(try PracticeHistory(fileURL: history.fileURL).load(), [first])
        let second = PracticeAttempt(question: PotOddsQuestion.examples[1], answer: 10)
        try history.save([first,second])
        assertEqual(try history.load(), [first,second])
        try history.save([])
        assertEqual(try history.load(), [])
    }

    func testHistoryRejectsDuplicateIDs() throws {
        let history = try temporaryHistory()
        let attempt = PracticeAttempt(question: PotOddsQuestion.examples[0], answer: 25)
        try history.save([attempt])
        let before = try Data(contentsOf: history.fileURL)
        assertThrowsError(try history.save([attempt,attempt]))
        assertEqual(try Data(contentsOf: history.fileURL), before)
        var document = try unwrap(JSONSerialization.jsonObject(with: before) as? [String:Any])
        let rows = try unwrap(document["attempts"] as? [[String:Any]])
        document["attempts"] = rows + rows
        try JSONSerialization.data(withJSONObject: document).write(to: history.fileURL)
        assertThrowsError(try history.load())
    }

    func testHistoryRejectsUnsupportedSchemaAndMalformedJSON() throws {
        let history = try temporaryHistory()
        try history.save([])
        try Data("{\"version\":99,\"attempts\":[]}".utf8).write(to: history.fileURL)
        assertThrowsError(try history.load())
        try Data("interrupted document".utf8).write(to: history.fileURL)
        assertThrowsError(try history.load())
    }

    func testHistoryRejectsOutOfRangeAnswerAndInconsistentCorrectness() throws {
        let history = try temporaryHistory()
        let attempt = PracticeAttempt(question: PotOddsQuestion.examples[0], answer: 25)
        try history.save([attempt])
        let savedData = try Data(contentsOf: history.fileURL)
        var envelope = try unwrap(JSONSerialization.jsonObject(with: savedData) as? [String:Any])
        var attempts = try unwrap(envelope["attempts"] as? [[String:Any]])
        attempts[0]["answer"] = 101
        envelope["attempts"] = attempts
        try JSONSerialization.data(withJSONObject: envelope).write(to: history.fileURL)
        assertThrowsError(try history.load())
        attempts[0]["answer"] = 25
        attempts[0]["isCorrect"] = false
        envelope["attempts"] = attempts
        try JSONSerialization.data(withJSONObject: envelope).write(to: history.fileURL)
        assertThrowsError(try history.load())
    }
}
