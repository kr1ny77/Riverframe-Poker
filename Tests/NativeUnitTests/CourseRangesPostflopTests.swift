import Foundation
import Testing
@testable import PokerCore

@Test func rangeAndPostflopBatchHasThreePurposesAndExplicitContexts() {
    let topics: Set<CourseTopicID> = [.t17, .t32, .t29, .t39, .t34, .t35, .t37]
    #expect(FoundationLesson.rangesPostflopExercises.count == 23)
    #expect(Set(FoundationLesson.rangesPostflopExercises.map(\.topicID)) == topics)
    for topic in topics {
        let tasks = FoundationLesson.rangesPostflopExercises.filter { $0.topicID == topic }
        #expect(tasks.count >= 3)
        #expect(Set(tasks.map(\.purpose)) == Set(FoundationPurpose.allCases))
        for task in tasks {
            #expect(!task.context.isEmpty && !task.explanation.isEmpty && !task.typicalError.isEmpty)
            #expect(task.researchAnchor == "nlhe-complete-knowledge-map.md#\(topic.rawValue.lowercased())")
            #expect(task.answer.accepts(task.answer.correctResponse))
            switch task.answer {
            case .number(let value, let tolerance):
                #expect(value.isFinite && tolerance.isFinite)
                #expect(!task.answer.accepts(.number(value + max(1, 2 * tolerance))))
                #expect(!task.answer.accepts(.choice(0)))
            case .choice(let options, let correct):
                #expect(options.indices.contains(correct))
                #expect(Set(options).count == options.count)
                #expect(!task.answer.accepts(.choice((correct + 1) % options.count)))
            }
        }
    }
}

@Test func bayesUsesIndependentNumeratorNormalizerAndChangedLikelihood() throws {
    #expect(abs(try CourseRangesMath.normalizerPercent(priorFirst: 0.4, likelihoodFirst: 0.8, priorSecond: 0.6, likelihoodSecond: 0.2) - 44) < 1e-10)
    #expect(abs(try CourseRangesMath.posteriorPercent(priorTarget: 0.4, likelihoodTarget: 0.8, priorOther: 0.6, likelihoodOther: 0.2) - 100 * 8.0 / 11) < 1e-10)
    #expect(abs(try CourseRangesMath.posteriorPercent(priorTarget: 0.4, likelihoodTarget: 0.8, priorOther: 0.6, likelihoodOther: 0.4) - 100 * 4.0 / 7) < 1e-10)
    #expect(try CourseRangesMath.weightedCombinations(count: 6, weight: 0.25) == 1.5)
}

@Test func postflopPricesAndRiverValueUseIndependentDenominators() throws {
    #expect(abs(try CourseRangesMath.callThresholdPercent(call: 3, finalPot: 14) - 150.0 / 7) < 1e-10)
    #expect(try CourseRangesMath.callThresholdPercent(call: 5, finalPot: 20) == 25)
    #expect(try CourseRangesMath.riverBetEV(equity: 0.75, finalPot: 70, bet: 20) == 32.5)
    #expect(try CourseRangesMath.bluffFoldThresholdPercent(pot: 30, bet: 20) == 40)
}

@Test func rangesRejectInvalidProbabilitiesNormalizersAndAmounts() {
    #expect(throws: (any Error).self) { try CourseRangesMath.posteriorPercent(priorTarget: 0.4, likelihoodTarget: 0.8, priorOther: 0.8, likelihoodOther: 0.2) }
    #expect(throws: (any Error).self) { try CourseRangesMath.posteriorPercent(priorTarget: 0.4, likelihoodTarget: 0, priorOther: 0.6, likelihoodOther: 0) }
    #expect(throws: (any Error).self) { try CourseRangesMath.normalizerPercent(priorFirst: .nan, likelihoodFirst: 0.8, priorSecond: 0.6, likelihoodSecond: 0.2) }
    #expect(throws: (any Error).self) { try CourseRangesMath.callThresholdPercent(call: 5, finalPot: 0) }
    #expect(throws: (any Error).self) { try CourseRangesMath.bluffFoldThresholdPercent(pot: .greatestFiniteMagnitude, bet: .greatestFiniteMagnitude) }
}

@Test func boardCompletersAndValueBranchesAgreeWithIndependentEvaluator() throws {
    let tasks = FoundationLesson.rangesPostflopExercises
    let board = [Card(id: 7), Card(id: 6), Card(id: 31)] // 9s 8s 7d
    let hero = [Card(id: 51), Card(id: 34)] // Ac Td
    let known = Set(hero + board)
    let ranks = Set((0..<52).map(Card.init(id:)).filter { !known.contains($0) }.filter {
        HandEvaluator.best(of: hero + board + [$0]).category == 4
    }.map(\.rank))
    #expect(ranks == [6, 11])
    let valueBoard = [Card(id: 36), Card(id: 44), Card(id: 15), Card(id: 0), Card(id: 33)]
    let heroRank = HandEvaluator.best(of: [Card(id: 12), Card(id: 49)] + valueBoard)
    #expect(HandEvaluator.best(of: [Card(id: 23), Card(id: 10)] + valueBoard) > heroRank)
    #expect(HandEvaluator.best(of: [Card(id: 48), Card(id: 47)] + valueBoard) < heroRank)
    #expect(tasks.first { $0.id.rawValue == "E.foundation.t37.river-value" }?.answer.accepts(.number(32.5)) == true)
    for task in tasks { #expect(Set(task.cards).count == task.cards.count) }
}
