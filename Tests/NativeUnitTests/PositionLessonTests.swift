import Foundation
import Testing
@testable import PokerCore

@Test func positionLessonSeatsAndAnswerKeys() throws {
    #expect(SixMaxPosition.preflopOrder.map(\.rawValue) == ["UTG","HJ","CO","BTN","SB","BB"])
    #expect(SixMaxPosition.postflopOrder.map(\.rawValue) == ["SB","BB","UTG","HJ","CO","BTN"])
    for button in 0..<6 {
        #expect(try SixMaxPosition.at(seat:button,button:button) == .btn)
        #expect(try SixMaxPosition.at(seat:(button+1)%6,button:button) == .sb)
        #expect(try SixMaxPosition.at(seat:(button+2)%6,button:button) == .bb)
        #expect(try SixMaxPosition.at(seat:(button+3)%6,button:button) == .utg)
        #expect(try SixMaxPosition.at(seat:(button+4)%6,button:button) == .hj)
        #expect(try SixMaxPosition.at(seat:(button+5)%6,button:button) == .co)
    }
    #expect(throws:PositionLessonError.invalidSeat) { try SixMaxPosition.at(seat:6,button:0) }
    #expect(throws:PositionLessonError.invalidSeat) { try SixMaxPosition.at(seat:0,button:-1) }
    let questions=PositionLesson.questions
    #expect(questions.count == 12 && Set(questions.map(\.id)).count == 12)
    for question in questions {
        #expect(question.choices.indices.contains(question.correctIndex))
        if question.recognition {
            let expected=try SixMaxPosition.at(seat:question.heroSeat,button:question.button)
            #expect(question.choices[question.correctIndex] == expected.rawValue)
        }
        for answer in question.choices.indices {
            let attempt=try PositionAttempt(question:question,answerIndex:answer)
            #expect(attempt.isValid && attempt.isCorrect == (answer == question.correctIndex))
        }
        for hand in question.hands { #expect(hand.count == 2 && Set(hand).count == 2) }
    }
    // Independently fixed keys for the two order questions and the four concepts.
    #expect(Array(questions.suffix(6)).map(\.correctIndex) == [0,1,0,1,1,1])
    let suited=questions[8].hands
    #expect(suited[0][0].suit == suited[0][1].suit)
    #expect(suited[1][0].suit != suited[1][1].suit)
    #expect(questions[9].hands[0][1].rank == 12 && questions[9].hands[1][1].rank == 11)
    #expect(throws:PositionLessonError.invalidAnswer) { try PositionAttempt(question:questions[0],answerIndex:-1) }
}

@Test func positionsMigrateLegacyArchivesAndRejectTampering() throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    let path=directory.appendingPathComponent("history.json"), history=PracticeHistory(fileURL:directory.appendingPathComponent("history.json"))
    let old=PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25)
    for version in [1,2] {
        var legacy:[String:Any] = ["version":version,"attempts":try JSONSerialization.jsonObject(with:JSONEncoder().encode([old]))]
        if version == 2 { legacy["comparisons"]=[] }
        let bytes=try JSONSerialization.data(withJSONObject:legacy)
        try bytes.write(to:path)
        #expect(try history.loadArchive() == PracticeArchive(attempts:[old]))
        #expect(try Data(contentsOf:path) == bytes)
    }
    let attempts=try PositionLesson.questions.enumerated().map { index,q in
        try PositionAttempt(question:q,answerIndex:index == 0 ? 1 : q.correctIndex)
    }
    let comparisonQ=HandComparisonLesson.questions(seed:5)[0]
    let comparison=HandComparisonAttempt(question:comparisonQ,answer:.bestFive(comparisonQ.firstRank.bestFive))
    try history.saveArchive(PracticeArchive(attempts:[old],comparisons:[comparison],positions:attempts))
    try history.save([old,PracticeAttempt(question:PotOddsQuestion.examples[1],answer:33.33)])
    let restored=try history.loadArchive()
    #expect(restored.positions == attempts && restored.positions.filter(\.isCorrect).count == 11)
    #expect(restored.comparisons == [comparison] && restored.attempts.count == 2)
    let good=try Data(contentsOf:path)
    let object=try #require(JSONSerialization.jsonObject(with:good) as? [String:Any])
    #expect(object["version"] as? Int == 7)
    for key in ["isCorrect","answerIndex","questionID","id"] {
        var bad=object
        var records=try #require(bad["positions"] as? [[String:Any]])
        switch key {
        case "isCorrect": records[0][key]=true
        case "answerIndex": records[0][key]=999
        case "questionID": records[0][key]="unknown-version"
        default: records[0][key]=old.id.uuidString
        }
        bad["positions"]=records
        let bytes=try JSONSerialization.data(withJSONObject:bad);try bytes.write(to:path)
        #expect(throws:(any Error).self) { try history.loadArchive() }
        #expect(try Data(contentsOf:path) == bytes)
    }
    try Data("{\"version\":3,\"attempts\":[],\"comparisons\":[]}".utf8).write(to:path)
    #expect(throws:(any Error).self) { try history.loadArchive() }
}
