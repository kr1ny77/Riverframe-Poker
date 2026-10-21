import Foundation
import Testing
@testable import PokerCore

/// Oracle visits the whole 52-choose-2 deck, independently of rank/suit generation.
private func comboOracle(_ hand:ComboHandClass,known:[Card]) -> Set<String> {
    var result=Set<String>()
    for a in 0..<52 {
        for b in (a+1)..<52 {
            if known.contains(where:{$0.id == a || $0.id == b}) { continue }
            let ranks=[a%13+2,b%13+2].sorted(by:>)
            guard ranks == [hand.high,hand.low] else { continue }
            let suited=a/13 == b/13
            if hand.kind == .suited && !suited || hand.kind == .offsuit && suited { continue }
            result.insert("\(a)-\(b)")
        }
    }
    return result
}

@Test func blockerAll169ClassesPartitionDeckAndRemoveExactly() throws {
    var union=Set<String>(), baselineTotal=0
    let q=BlockerQuestion.examples[3]
    for high in 2...14 {
        for low in 2...high {
            for kind in (high == low ? [ComboKind.pair] : [.suited,.offsuit]) {
                let hand=try ComboHandClass(high:high,low:low,kind:kind)
                let entry=try BlockerRangeEntry(hand:hand,role:.count,weight:1)
                let row=BlockerRow(entry:entry,hero:q.hero,board:q.board)
                #expect(hand.combinations.count == (kind == .pair ? 6 : (kind == .suited ? 4 : 12)))
                let baseline=Set(row.baseline.map(\.id)), afterHero=Set(row.afterHero.map(\.id)), remaining=Set(row.remaining.map(\.id))
                #expect(baseline == comboOracle(hand,known:[]))
                #expect(afterHero == comboOracle(hand,known:q.hero))
                #expect(remaining == comboOracle(hand,known:q.hero+q.board))
                #expect(union.isDisjoint(with:baseline));union.formUnion(baseline);baselineTotal+=baseline.count
                let excluded=Set(row.exclusions.map(\.id))
                #expect(excluded.count == row.exclusions.count && excluded.isDisjoint(with:remaining))
                #expect(excluded.union(remaining) == baseline)
                for exclusion in row.exclusions {
                    #expect(!exclusion.blockers.isEmpty)
                    #expect(exclusion.blockers.allSatisfy { exclusion.combo.cards.contains($0) && (exclusion.stage == "Hero" ? q.hero : q.board).contains($0) })
                    if exclusion.stage == "доска" { #expect(Set(exclusion.combo.cards).isDisjoint(with:Set(q.hero))) }
                }
            }
        }
    }
    #expect(union.count == 1326 && baselineTotal == 1326)
}

@Test func blockerLessonVectorsWeightsAndCounterexample() throws {
    let questions=BlockerQuestion.examples
    let counts=[[6,3,1],[4,2,1],[12,7,5]]
    for i in 0..<3 {
        let row=questions[i].rows[0]
        #expect([row.baseline.count,row.afterHero.count,row.remaining.count] == counts[i])
    }
    #expect(questions[2].rows[0].remaining.map(\.id).sorted() == ["11-38","24-38","38-50","11-51","24-51"].sorted())
    #expect(questions.map(\.remainingCount) == [1,1,5,4,4,5])
    #expect(questions.map(\.correctIndex) == [1,2,0,1,0,2])
    #expect(questions[3].bluffPercent == 75 && questions[3].valueMass == 1 && questions[3].bluffMass == 3)
    #expect(questions[4].bluffPercent == 50 && questions[4].valueMass == 3 && questions[4].bluffMass == 3)
    #expect(questions[5].bluffPercent == 40 && questions[5].valueMass == 3 && questions[5].bluffMass == 2)
    for q in questions {
        for choice in q.choices.indices {
            let attempt=try BlockerAttempt(questionID:q.id,answerIndex:choice)
            #expect(attempt.isValid && attempt.isCorrect == (choice == q.correctIndex))
        }
        let swapped=try BlockerQuestion(id:"swapped",hero:q.hero.reversed(),board:q.board.reversed(),range:q.range.reversed(),metric:q.metric,choices:q.choices)
        #expect(swapped.remainingCount == q.remainingCount && swapped.bluffPercent == q.bluffPercent)
        if q.isRangeModel {
            let hero=independentSevenCardRank(q.hero+q.board)
            for row in q.rows {
                for combo in row.remaining {
                    let opponent=independentSevenCardRank(combo.cards+q.board)
                    #expect(row.entry.role == .value ? hero.lexicographicallyPrecedes(opponent) : opponent.lexicographicallyPrecedes(hero))
                }
            }
            let scaled=try q.range.map { try BlockerRangeEntry(hand:$0.hand,role:$0.role,weight:$0.weight*2) }
            let copy=try BlockerQuestion(id:"scaled",hero:q.hero,board:q.board,range:scaled,metric:q.metric,choices:q.choices)
            #expect(copy.bluffPercent == q.bluffPercent && copy.remainingCount == q.remainingCount)
        }
    }
    let aa=questions[0].rows[0]
    let both=try #require(aa.exclusions.first { Set($0.combo.cards) == Set([Card(id:12),Card(id:25)]) })
    #expect(both.stage == "Hero") // A♠A♥ is removed once, before the board step.
}

@Test func blockerInputValidationAndEmptyRange() throws {
    let q=BlockerQuestion.examples[0]
    #expect(throws:BlockerError.invalidClass) { try ComboHandClass(high:15,low:14,kind:.suited) }
    #expect(throws:BlockerError.invalidClass) { try ComboHandClass(high:14,low:13,kind:.pair) }
    #expect(throws:BlockerError.invalidClass) { try ComboHandClass(high:14,low:14,kind:.offsuit) }
    for weight in [0,-1,1001] { #expect(throws:BlockerError.invalidRange) { try BlockerRangeEntry(hand:q.range[0].hand,role:.value,weight:weight) } }
    #expect(throws:BlockerError.invalidCards) { try BlockerQuestion(id:"bad",hero:[q.hero[0],q.hero[0]],board:q.board,range:q.range,metric:q.metric,choices:q.choices) }
    #expect(throws:BlockerError.invalidCards) { try BlockerQuestion(id:"bad",hero:q.hero,board:[q.hero[0]]+q.board,range:q.range,metric:q.metric,choices:q.choices) }
    for range in [[],[q.range[0],q.range[0]]] {
        #expect(throws:BlockerError.invalidRange) { try BlockerQuestion(id:"bad",hero:q.hero,board:q.board,range:range,metric:q.metric,choices:q.choices) }
    }
    let empty=try BlockerQuestion(id:"empty",hero:[Card(id:12),Card(id:38)],board:[Card(id:25),Card(id:51),Card(id:39)],range:[.init(hand:q.range[0].hand,role:.value,weight:1)],metric:.bluffPercent,choices:[0,100])
    #expect(empty.remainingCount == 0 && empty.bluffPercent == nil && empty.correctIndex == nil)
    #expect(throws:BlockerError.invalidAnswer) { try BlockerAttempt(questionID:"unknown",answerIndex:0) }
    #expect(throws:BlockerError.invalidAnswer) { try BlockerAttempt(questionID:q.id,answerIndex:999) }
}

@Test func blockerArchiveMigrationAndTampering() throws {
    let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:folder) }
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    let file=folder.appendingPathComponent("history.json"), history=PracticeHistory(fileURL:folder.appendingPathComponent("history.json"))
    let old=PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25)
    let ev=try EVCallAttempt(question:EVCallQuestion.examples[0],decision:.call)
    for version in 1...4 {
        var doc:[String:Any]=["version":version,"attempts":try JSONSerialization.jsonObject(with:JSONEncoder().encode([old]))]
        if version>=2 { doc["comparisons"]=[] }
        if version>=3 { doc["positions"]=[] }
        if version>=4 { doc["evCalls"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode([ev])) }
        let bytes=try JSONSerialization.data(withJSONObject:doc);try bytes.write(to:file)
        let archive=try history.loadArchive()
        #expect(archive.blockers.isEmpty && archive.attempts == [old] && archive.evCalls == (version == 4 ? [ev] : []))
        #expect(try Data(contentsOf:file) == bytes)
    }
    let attempts=try BlockerQuestion.examples.map { try BlockerAttempt(questionID:$0.id,answerIndex:$0.correctIndex!) }
    let position=try PositionAttempt(question:PositionLesson.questions[0],answerIndex:0)
    let comparisonQ=HandComparisonLesson.questions(seed:2)[0]
    let comparison=HandComparisonAttempt(question:comparisonQ,answer:.bestFive(comparisonQ.firstRank.bestFive))
    try history.saveArchive(PracticeArchive(attempts:[old],comparisons:[comparison],positions:[position],evCalls:[ev],blockers:attempts))
    try history.save([old])
    let restored=try history.loadArchive()
    #expect(restored.blockers == attempts && restored.evCalls == [ev] && restored.positions == [position] && restored.comparisons == [comparison])
    let object=try #require(JSONSerialization.jsonObject(with:Data(contentsOf:file)) as? [String:Any])
    #expect(object["version"] as? Int == 6)
    for key in ["isCorrect","answerIndex","questionID","id","missing"] {
        var bad=object
        var rows=try #require(bad["blockers"] as? [[String:Any]])
        switch key {
        case "isCorrect":rows[0][key]=false
        case "answerIndex":rows[0][key]=999
        case "questionID":rows[0][key]="unknown"
        case "id":rows[0][key]=ev.id.uuidString
        default:break
        }
        bad["blockers"]=rows
        if key == "missing" { bad.removeValue(forKey:"blockers") }
        let bytes=try JSONSerialization.data(withJSONObject:bad);try bytes.write(to:file)
        #expect(throws:(any Error).self) { try history.loadArchive() }
        #expect(try Data(contentsOf:file) == bytes)
    }
}
