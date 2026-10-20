import Foundation
import Testing
@testable import PokerCore

@Test func rangeEquityExactWeightedOracle() throws {
    for question in RangeEquityQuestion.examples {
        let actual=try question.calculate()
        var oracleWins=0, oracleTies=0, oracleLosses=0
        for row in actual.rows {
            let excluded=Set(question.hero + question.board + row.hand.cards)
            let deck=(0..<52).filter { !excluded.contains(Card(id:$0)) }
            var wins=0, ties=0, losses=0
            func evaluate(_ ids:[Int]) {
                let board=question.board+ids.map(Card.init(id:))
                let first=independentSevenCardRank(question.hero+board)
                let second=independentSevenCardRank(row.hand.cards+board)
                if first == second { ties += 1 }
                else if second.lexicographicallyPrecedes(first) { wins += 1 }
                else { losses += 1 }
            }
            for first in deck {
                if question.board.count == 4 { evaluate([first]) }
                else { for second in deck where first != second { evaluate([first,second]) } }
            }
            let factor=question.board.count == 3 ? 2 : 1
            let actualCounts: [Int] = [row.outcomes.wins,row.outcomes.ties,row.outcomes.losses]
            let referenceCounts: [Int] = [wins/factor,ties/factor,losses/factor]
            #expect(actualCounts == referenceCounts)
            oracleWins += row.hand.weight*wins/factor
            oracleTies += row.hand.weight*ties/factor
            oracleLosses += row.hand.weight*losses/factor
        }
        #expect(actual.weightedWins == oracleWins && actual.weightedTies == oracleTies && actual.weightedLosses == oracleLosses)
        #expect(actual.evaluatedOutcomes == (question.board.count == 3 ? 1980 : 88))
        #expect(actual.weightedTotal == (question.board.count == 3 ? 3960 : 176))
        #expect(abs(actual.equityPercent-100*Double(2*oracleWins+oracleTies)/Double(2*(oracleWins+oracleTies+oracleLosses))) < 1e-12)
        print("RANGE EXACT \(question.id): W/T/L=\(oracleWins)/\(oracleTies)/\(oracleLosses); evaluations=\(actual.evaluatedOutcomes); equity=\(actual.equityPercent)")
    }
    #expect(try RangeEquityQuestion.examples[1].calculate().equityPercent == 87.5)
    #expect(try RangeEquityQuestion.examples[2].calculate().equityPercent == 62.5)
}

@Test func rangeEquityValidationScalingAndPersistence() throws {
    let q=RangeEquityQuestion.examples[1]
    let cards=q.range[0].cards
    for weight in [0,-1,1001] {
        #expect(throws:RangeEquityError.invalidWeight) { try WeightedOpponentHand(cards:cards,weight:weight) }
    }
    #expect(throws:RangeEquityError.invalidSize) { try RangeEquityQuestion(id:"bad",hero:q.hero,board:q.board,range:[]) }
    #expect(throws:RangeEquityError.invalidSize) { try RangeEquityQuestion(id:"bad",hero:q.hero,board:q.board,range:Array(repeating:q.range[0],count:9)) }
    let reversed=try WeightedOpponentHand(cards:Array(cards.reversed()),weight:3)
    #expect(throws:RangeEquityError.duplicateHand) { try RangeEquityQuestion(id:"bad",hero:q.hero,board:q.board,range:[q.range[0],reversed]) }
    let blocked=try WeightedOpponentHand(cards:[q.hero[0],cards[0]],weight:1)
    #expect(throws:EquityLessonError.invalidCards) { try RangeEquityQuestion(id:"bad",hero:q.hero,board:q.board,range:[blocked]) }
    let boardBlocked=try WeightedOpponentHand(cards:[q.board[0],cards[0]],weight:1)
    #expect(throws:EquityLessonError.invalidCards) { try RangeEquityQuestion(id:"bad",hero:q.hero,board:q.board,range:[boardBlocked]) }
    #expect(throws:EquityLessonError.invalidCards) { try WeightedOpponentHand(cards:[cards[0],cards[0]],weight:1) }
    let scaled=try RangeEquityQuestion(id:"scaled",hero:q.hero,board:q.board,range:q.range.map { try .init(cards:$0.cards,weight:10*$0.weight) })
    #expect(try scaled.calculate().equityPercent == q.calculate().equityPercent)
    // Cards can occur in separate alternative hands; only one hand is present in each branch.
    let overlapping=try RangeEquityQuestion(id:"overlap",hero:q.hero,board:q.board,range:[q.range[0],.init(cards:[cards[0],Card(id:48)],weight:1)])
    #expect(try overlapping.calculate().evaluatedOutcomes == 88)
    let single=try RangeEquityQuestion(id:"one",hero:q.hero,board:q.board,range:[q.range[0]])
    #expect(try single.calculate().equityPercent == 50)
    let result=try q.calculate()
    let correct=PracticeAttempt(question:q,result:result,answer:87.5)
    let wrong=PracticeAttempt(question:q,result:result,answer:0)
    #expect(correct.topic == .rangeEquity && correct.isCorrect && !wrong.isCorrect)
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let history=PracticeHistory(fileURL:directory.appendingPathComponent("practice.json"))
    let known=KnownHandEquityQuestion.examples[1]
    let old=PracticeAttempt(question:known,result:try known.calculate(),answer:50)
    try history.save([old,correct,wrong])
    #expect(try history.load() == [old,correct,wrong])
}
