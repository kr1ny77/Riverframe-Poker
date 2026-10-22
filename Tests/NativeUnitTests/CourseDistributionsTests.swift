import Foundation
import Testing
@testable import PokerCore

@Test func distributionLessonsHaveThreePurposesAndCompletePassports() {
    let topics: Set<CourseTopicID> = [.t30, .t31, .t33, .t40]
    #expect(FoundationLesson.distributionExercises.count == 13)
    #expect(Set(FoundationLesson.distributionExercises.map(\.topicID)) == topics)
    for topic in topics {
        let exercises = FoundationLesson.distributionExercises.filter { $0.topicID == topic }
        #expect(Set(exercises.map(\.purpose)) == Set(FoundationPurpose.allCases))
        for exercise in exercises {
            #expect(exercise.id.rawValue.hasPrefix("E.foundation.\(topic.rawValue.lowercased())."))
            #expect(!exercise.context.isEmpty && !exercise.explanation.isEmpty)
            #expect(!exercise.assumptions.isEmpty && !exercise.researchAnchor.isEmpty)
            #expect(exercise.answer.accepts(exercise.answer.correctResponse))
            if case .number(let value, let tolerance) = exercise.answer {
                #expect(!exercise.answer.accepts(.number(value + max(1, tolerance * 2))))
            }
        }
    }
}

@Test func distributionMathUsesDeclaredDenominatorsAndSupportsAboveHundredEQR() throws {
    #expect(try CourseDistributionMath.weightedMass(6, weight: 0.5) == 3)
    #expect(try CourseDistributionMath.equityRealizationPercent(futureNetEV: 30, pot: 100, rawEquity: 0.4) == 75)
    #expect(try CourseDistributionMath.equityRealizationPercent(futureNetEV: 15, pot: 50, rawEquity: 0.25) == 120)
    #expect(try CourseDistributionMath.multiwayCallThresholdPercent(call: 9, accessibleFinalPot: 45) == 20)
    #expect(try CourseDistributionMath.expectedSharePercent(outcomeProbabilities: [0.5, 0.25, 0.25], shares: [1, 0.5, 0]) == 62.5)
}

@Test func distributionMathRejectsInvalidInputsAndCorruptJointModels() {
    #expect(throws: (any Error).self) { try CourseDistributionMath.weightedMass(2, weight: 1.1) }
    #expect(throws: (any Error).self) { try CourseDistributionMath.equityRealizationPercent(futureNetEV: 2, pot: 0, rawEquity: 0.5) }
    #expect(throws: (any Error).self) { try CourseDistributionMath.equityRealizationPercent(futureNetEV: 2, pot: 4, rawEquity: 0) }
    #expect(throws: (any Error).self) { try CourseDistributionMath.multiwayCallThresholdPercent(call: 6, accessibleFinalPot: 5) }
    #expect(throws: (any Error).self) { try CourseDistributionMath.expectedSharePercent(outcomeProbabilities: [0.4, 0.4], shares: [1, 0]) }
}

@Test func physicalBoardsAndMadeHandExamplesAgreeWithEvaluator() throws {
    let k72 = [Card(id: 11), Card(id: 31), Card(id: 39)] // K♠ 7♦ 2♣
    let kings = HandEvaluator.best(of: [Card(id: 24), Card(id: 37)] + k72)
    let sevens = HandEvaluator.best(of: [Card(id: 5), Card(id: 18)] + k72)
    #expect(kings.category == 3)
    #expect(sevens.category == 3)
    #expect(kings > sevens)

    let lowBoard = [Card(id: 4), Card(id: 42), Card(id: 2)] // 6♠ 5♣ 4♠
    let suited76 = [[Card(id: 17), Card(id: 18)], [Card(id: 30), Card(id: 31)], [Card(id: 43), Card(id: 44)]]
    #expect(suited76.allSatisfy { Set($0 + lowBoard).count == 5 })
    #expect(suited76.allSatisfy { $0[0].rank == 6 && $0[1].rank == 7 && $0[0].suit == $0[1].suit })

    let river = [Card(id: 11), Card(id: 31), Card(id: 39), Card(id: 20), Card(id: 40)] // K♠ 7♦ 2♣ 9♥ 3♣
    let rangeA = [[Card(id: 24), Card(id: 37)], [Card(id: 51), Card(id: 38)]] // K♥K♦, A♣A♦
    let rangeB = [[Card(id: 5), Card(id: 18)], [Card(id: 12), Card(id: 49)]] // 7♠7♥, A♠Q♣
    let outcomes = rangeA.flatMap { hero in rangeB.map { villain in HandEvaluator.best(of: hero + river) > HandEvaluator.best(of: villain + river) } }
    #expect(outcomes.filter { $0 }.count == 3)
    #expect(try CourseDistributionMath.expectedSharePercent(outcomeProbabilities: Array(repeating: 0.25, count: 4), shares: outcomes.map { $0 ? 1 : 0 }) == 75)
}
