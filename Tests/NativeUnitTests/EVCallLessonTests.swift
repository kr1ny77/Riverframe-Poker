import Foundation
import Testing
@testable import PokerCore

@Test func evCallExactExamplesAgainstIndependentBranches() throws {
    let expectedEquity=[40.0,20.0,25.0], expectedEV=[30.0,-10.0,0.0]
    let expectedWeights=[[2,0,3],[1,0,4],[0,1,1]]
    for (index,q) in EVCallQuestion.examples.enumerated() {
        let result=q.result
        #expect(result.equityPercent == expectedEquity[index])
        #expect(result.callEV == expectedEV[index] && result.foldEV == 0)
        #expect(q.thresholdPercent == 25 && q.finalPot == 200)
        #expect([result.weightedWins,result.weightedTies,result.weightedLosses] == expectedWeights[index])
        let hero=independentSevenCardRank(q.hero+q.board)
        #expect(hero == [1,14,12,9,7])
        var branchEV=0.0
        for hand in q.range {
            let opponent=independentSevenCardRank(hand.cards+q.board)
            let net = hero == opponent ? 50.0 : (opponent.lexicographicallyPrecedes(hero) ? 150.0 : -50.0)
            branchEV += net*Double(hand.weight)/Double(result.totalWeight)
        }
        #expect(branchEV == expectedEV[index])
        for decision in EVDecision.allCases {
            let expected=index == 2 || decision == (index == 0 ? .call : .fold)
            let attempt=try EVCallAttempt(question:q,decision:decision)
            #expect(attempt.isCorrect == expected && attempt.isValid)
        }
    }
    let q=EVCallQuestion.examples[2]
    let tied=try EVCallQuestion(id:"all-ties",hero:q.hero,board:q.board,range:[q.range[1]],potBefore:100,opponentBet:50)
    #expect(tied.result.equityPercent == 50 && tied.result.callEV == 50)
    let scaled=try EVCallQuestion(id:"large",hero:q.hero,board:q.board,range:q.range,potBefore:1_000_000_000,opponentBet:500_000_000)
    #expect(scaled.result.callEVNumerator == 0)
}

@Test func evCallRejectsInvalidInputsAndQuestionSubstitution() throws {
    let q=EVCallQuestion.examples[0]
    for values in [(Int64(0),Int64(50)),(100,0),(101,50),(100,-1),(1_000_000_001,50)] {
        #expect(throws:EVCallError.invalidAmounts) { try EVCallQuestion(id:"bad",hero:q.hero,board:q.board,range:q.range,potBefore:values.0,opponentBet:values.1) }
    }
    #expect(throws:EVCallError.invalidRange) { try EVCallQuestion(id:"bad",hero:q.hero,board:q.board,range:[],potBefore:100,opponentBet:50) }
    #expect(throws:EVCallError.invalidRange) { try EVCallQuestion(id:"bad",hero:q.hero,board:q.board,range:[q.range[0],q.range[0]],potBefore:100,opponentBet:50) }
    for replacement in q.hero+q.board {
        let hand=try WeightedOpponentHand(cards:[replacement,Card(id:50)],weight:1)
        #expect(throws:EVCallError.invalidCards) { try EVCallQuestion(id:"bad",hero:q.hero,board:q.board,range:[hand],potBefore:100,opponentBet:50) }
    }
    #expect(throws:EVCallError.invalidCards) { try EVCallQuestion(id:"bad",hero:q.hero,board:Array(q.board.prefix(4)),range:q.range,potBefore:100,opponentBet:50) }
    let substitute=try EVCallQuestion(id:q.id,hero:q.hero,board:q.board,range:q.range,potBefore:200,opponentBet:50)
    #expect(throws:EVCallError.unknownQuestion) { try EVCallAttempt(question:substitute,decision:.call) }
}

@Test func evCallArchiveMigrationMixedWritesAndTampering() throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    let path=directory.appendingPathComponent("history.json"), history=PracticeHistory(fileURL:directory.appendingPathComponent("history.json"))
    let old=PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25)
    let position=try PositionAttempt(question:PositionLesson.questions[0],answerIndex:0)
    let comparisonQ=HandComparisonLesson.questions(seed:9)[0]
    let comparison=HandComparisonAttempt(question:comparisonQ,answer:.bestFive(comparisonQ.firstRank.bestFive))
    for version in 1...3 {
        var document:[String:Any]=["version":version,"attempts":try JSONSerialization.jsonObject(with:JSONEncoder().encode([old]))]
        if version >= 2 { document["comparisons"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode([comparison])) }
        if version >= 3 { document["positions"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode([position])) }
        let bytes=try JSONSerialization.data(withJSONObject:document);try bytes.write(to:path)
        let archive=try history.loadArchive()
        #expect(archive.evCalls.isEmpty && archive.attempts == [old])
        #expect(archive.comparisons == (version >= 2 ? [comparison] : []))
        #expect(archive.positions == (version >= 3 ? [position] : []))
        #expect(try Data(contentsOf:path) == bytes)
    }
    let ev=try EVCallAttempt(question:EVCallQuestion.examples[0],decision:.call)
    try history.saveArchive(PracticeArchive(attempts:[old],comparisons:[comparison],positions:[position],evCalls:[ev]))
    try history.save([old,PracticeAttempt(question:PotOddsQuestion.examples[1],answer:33.33)])
    let restored=try history.loadArchive()
    #expect(restored.evCalls == [ev] && restored.positions == [position] && restored.comparisons == [comparison] && restored.attempts.count == 2)
    let good=try Data(contentsOf:path)
    let object=try #require(JSONSerialization.jsonObject(with:good) as? [String:Any])
    #expect(object["version"] as? Int == 5)
    for key in ["isCorrect","questionID","decision","id"] {
        var bad=object
        var records=try #require(bad["evCalls"] as? [[String:Any]])
        switch key {
        case "isCorrect":records[0][key]=false
        case "questionID":records[0][key]="unknown"
        case "decision":records[0][key]="raise"
        default:records[0][key]=position.id.uuidString
        }
        bad["evCalls"]=records
        let bytes=try JSONSerialization.data(withJSONObject:bad);try bytes.write(to:path)
        #expect(throws:(any Error).self) { try history.loadArchive() }
        #expect(try Data(contentsOf:path) == bytes)
    }
    var missing=object;missing.removeValue(forKey:"evCalls")
    try JSONSerialization.data(withJSONObject:missing).write(to:path)
    #expect(throws:(any Error).self) { try history.loadArchive() }
}
