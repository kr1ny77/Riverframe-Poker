import Foundation
import Testing
@testable import PokerCore

@Test func riskLessonsCoverFiveTopicsWithThreePurposes() {
    let topics: Set<CourseTopicID> = [.t55, .t56, .t57, .t58, .t59]
    #expect(FoundationLesson.riskExercises.count == 15)
    #expect(Set(FoundationLesson.riskExercises.map(\.topicID)) == topics)
    for topic in topics {
        let group = FoundationLesson.riskExercises.filter { $0.topicID == topic }
        #expect(Set(group.map(\.purpose)) == Set(FoundationPurpose.allCases))
        #expect(group.allSatisfy { $0.answer.accepts($0.answer.correctResponse) })
        #expect(group.allSatisfy { !$0.context.isEmpty && !$0.explanation.isEmpty && !$0.assumptions.isEmpty })
    }
}

@Test func riskMathMatchesIndependentWorkedValues() throws {
    #expect(try CourseRiskMath.eventualRuinProbability(winProbability: 0.5, capital: 10) == 1)
    let independentRuin = pow(0.45 / 0.55, 20)
    #expect(abs(try CourseRiskMath.eventualRuinProbability(winProbability: 0.55, capital: 20) - independentRuin) < 1e-12)
    let independentPosterior = (0.5 * 0.4) / ((0.5 * 0.4) + (0.5 * 0.2))
    #expect(abs(try CourseRiskMath.posterior(prior: 0.5, signalGivenHypothesis: 0.4, signalGivenAlternative: 0.2) - independentPosterior) < 1e-12)
    #expect(try CourseRiskMath.percentage(numerator: 14, denominator: 20) == 70)
}

@Test func riskMathRejectsBrokenModelsAndUnknownSignalDenominator() throws {
    #expect(throws: (any Error).self) { try CourseRiskMath.eventualRuinProbability(winProbability: .nan, capital: 2) }
    #expect(try CourseRiskMath.eventualRuinProbability(winProbability: 0.6, capital: 0) == 1)
    #expect(throws: (any Error).self) { try CourseRiskMath.posterior(prior: 0.2, signalGivenHypothesis: 0, signalGivenAlternative: 0) }
    #expect(throws: (any Error).self) { try CourseRiskMath.percentage(numerator: 21, denominator: 20) }
    #expect(throws: (any Error).self) { try CourseRiskMath.percentage(numerator: 1, denominator: 0) }
}

@Test func riskExercisesKeepNoiseAndPersonalBoundariesOutOfNumericClaims() {
    let tells = FoundationLesson.riskExercises.filter { $0.topicID == .t58 }
    #expect(tells.contains { $0.id.rawValue == "E.foundation.t58.unknown-likelihood" && $0.answer.accepts(.choice(1)) })
    let support = FoundationLesson.riskExercises.filter { $0.topicID == .t59 }
    #expect(support.allSatisfy { $0.resultKind == .definitions })
    #expect(!FoundationLesson.riskExercises.flatMap(\.context).joined(separator: " ").contains("гарантированная прибыль"))
}
