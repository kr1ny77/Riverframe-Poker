import Foundation
import Testing
@testable import PokerCore

private func comparisonFixture() -> HandComparisonAttempt {
    let question = HandComparisonLesson.questions(seed:7)[0]
    let answer: HandComparisonAnswer = question.mode == .winner ? .winner(question.winner) : .bestFive(question.firstRank.bestFive)
    return HandComparisonAttempt(question:question,answer:answer)
}
private func archivePath() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("ComparisonArchive-\(UUID().uuidString)/practice-v1.json")
}

@Test func legacyV1MigratesAtomicallyAndNumericWritesPreserveComparisons() throws {
    let path=archivePath(); defer { try? FileManager.default.removeItem(at:path.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(at:path.deletingLastPathComponent(),withIntermediateDirectories:true)
    let old=PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25)
    let legacy: [String:Any] = ["version":1,"attempts":try JSONSerialization.jsonObject(with:JSONEncoder().encode([old]))]
    let bytes=try JSONSerialization.data(withJSONObject:legacy)
    try bytes.write(to:path)
    let history=PracticeHistory(fileURL:path)
    #expect(try history.loadArchive()==PracticeArchive(attempts:[old]))
    #expect(try Data(contentsOf:path)==bytes)
    let new=comparisonFixture()
    try history.saveArchive(PracticeArchive(attempts:[old],comparisons:[new]))
    #expect(try history.loadArchive()==PracticeArchive(attempts:[old],comparisons:[new]))
    let second=PracticeAttempt(question:FlushDrawLesson.standard.questions[0],answer:19.1)
    try history.save([old,second])
    #expect(try history.loadArchive()==PracticeArchive(attempts:[old,second],comparisons:[new]))
    let object=try #require(JSONSerialization.jsonObject(with:Data(contentsOf:path)) as? [String:Any])
    #expect(object["version"] as? Int == 5)
    try history.saveArchive(PracticeArchive())
    #expect(try history.loadArchive()==PracticeArchive())
}

@Test func categoricalArchiveRejectsTamperedGradeAndDuplicateIdentity() throws {
    let path=archivePath();defer { try? FileManager.default.removeItem(at:path.deletingLastPathComponent()) }
    let history=PracticeHistory(fileURL:path)
    let old=PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25)
    let new=comparisonFixture()
    try history.saveArchive(PracticeArchive(attempts:[old],comparisons:[new]))
    let good=try Data(contentsOf:path)
    var document=try #require(JSONSerialization.jsonObject(with:good) as? [String:Any])
    var records=try #require(document["comparisons"] as? [[String:Any]])
    records[0]["isCorrect"] = !new.isCorrect
    document["comparisons"]=records
    let bad=try JSONSerialization.data(withJSONObject:document)
    try bad.write(to:path)
    #expect(throws:(any Error).self) { try history.loadArchive() }
    #expect(try Data(contentsOf:path)==bad)
    document=try #require(JSONSerialization.jsonObject(with:good) as? [String:Any])
    records=try #require(document["comparisons"] as? [[String:Any]])
    records[0]["id"]=old.id.uuidString
    document["comparisons"]=records
    try JSONSerialization.data(withJSONObject:document).write(to:path)
    #expect(throws:(any Error).self) { try history.loadArchive() }
    try Data("{\"version\":2,\"attempts\":[]}".utf8).write(to:path)
    #expect(throws:(any Error).self) { try history.loadArchive() }
}


@Test func fullLessonMixedAnswersPersistAndRestore() throws {
    let path=archivePath();defer { try? FileManager.default.removeItem(at:path.deletingLastPathComponent()) }
    let history=PracticeHistory(fileURL:path)
    let questions=HandComparisonLesson.questions(seed:29)
    let attempts=questions.enumerated().map { index, question -> HandComparisonAttempt in
        let answer: HandComparisonAnswer
        if question.mode == .winner {
            answer = .winner(index.isMultiple(of:3) ? question.winner : (question.winner == .first ? .second : .first))
        } else {
            let cards: [Card]
            if index.isMultiple(of:3) {
                cards = question.firstRank.bestFive
            } else {
                cards = question.board
            }
            answer = .bestFive(cards)
        }
        return HandComparisonAttempt(question:question,answer:answer)
    }
    let attemptsAreValid = attempts.map { $0.isValid }.allSatisfy { $0 }
    #expect(attemptsAreValid)
    try history.saveArchive(PracticeArchive(comparisons:attempts))
    let restored=try history.loadArchive().comparisons
    #expect(restored==attempts)
    #expect(restored.count==12)
    #expect(restored.filter(\.isCorrect).count==attempts.filter(\.isCorrect).count)
    #expect(restored.map(\.answer)==attempts.map(\.answer))
    #expect(Set(restored.map(\.question.id))==Set(questions.map(\.id)))
}
