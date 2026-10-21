import Testing
@testable import PokerCore

@Test func foundationRulesExercisesHaveStableCoverageAndTeachingFields() {
    let exercises = FoundationLesson.rulesExercises
    #expect(exercises.count == 17)
    #expect(Set(exercises.map(\.id)).count == 17)

    for topic in [CourseTopicID.t03, .t04, .t05] {
        let topicExercises = exercises.filter { $0.topicID == topic }
        #expect(Set(topicExercises.map(\.purpose)) == Set(FoundationPurpose.allCases))
        #expect(topicExercises.count >= 3)
        #expect(topicExercises.allSatisfy { !$0.context.isEmpty && !$0.question.isEmpty && !$0.explanation.isEmpty })
        #expect(topicExercises.allSatisfy { !$0.typicalError.isEmpty && !$0.term.isEmpty && !$0.definition.isEmpty && !$0.example.isEmpty && !$0.method.isEmpty && !$0.assumptions.isEmpty })
        #expect(topicExercises.allSatisfy { !$0.diagram.isEmpty && $0.researchAnchor == "nlhe-complete-knowledge-map.md#\(topic.rawValue.lowercased())" })
    }
}

@Test func sprExamplesMatchIndependentResearchConstants() throws {
    #expect(try FoundationRulesMath.effectiveStack(heroRemaining: 120, opponentRemaining: 70) == 70)
    #expect(try FoundationRulesMath.spr(effectiveRemaining: 200, pot: 50) == 4)
    #expect(try FoundationRulesMath.spr(effectiveRemaining: 70, pot: 35) == 2)
    #expect(try FoundationRulesMath.potAfterBetAndCall(pot: 30, bet: 15) == 60)
    #expect(try FoundationRulesMath.spr(effectiveRemaining: 75, pot: 60) == 1.25)
}

@Test func raisingExamplesMatchIndependentResearchConstants() throws {
    #expect(try FoundationRulesMath.minimumRaiseTo(currentBet: 20, lastFullRaise: 20) == 40)
    #expect(try FoundationRulesMath.minimumRaiseTo(currentBet: 60, lastFullRaise: 40) == 100)
    #expect(try FoundationRulesMath.actionReopens(previousBet: 30, currentBet: 50, lastFullRaise: 20))
    #expect(try FoundationRulesMath.minimumRaiseTo(currentBet: 50, lastFullRaise: 20) == 70)
    #expect(try FoundationRulesMath.callContribution(currentBet: 50, alreadyContributed: 20, remainingStack: 17) == 17)
}

@Test func sidePotExamplesMatchIndependentResearchConstants() throws {
    #expect(try FoundationRulesMath.potLayer(lower: 0, upper: 50, contributions: [50, 100, 100]) == 150)
    #expect(try FoundationRulesMath.potLayer(lower: 30, upper: 70, contributions: [30, 70, 70, 100]) == 120)
    #expect(try FoundationRulesMath.uncalledReturn(contributions: [30, 70, 70, 100]) == 30)
    let shares = try FoundationRulesMath.oddChipShares(pot: 101, winnerCount: 2)
    #expect(shares.base == 50 && shares.oddChips == 1)
}

@Test func foundationRulesMathRejectsInvalidInputs() {
    #expect(throws: FoundationRulesMathError.nonPositivePot) { try FoundationRulesMath.spr(effectiveRemaining: 100, pot: 0) }
    #expect(throws: FoundationRulesMathError.invalidAmount) { try FoundationRulesMath.effectiveStack(heroRemaining: -.infinity, opponentRemaining: 30) }
    #expect(throws: FoundationRulesMathError.invalidBetSequence) { try FoundationRulesMath.actionReopens(previousBet: 50, currentBet: 45, lastFullRaise: 20) }
    #expect(throws: FoundationRulesMathError.insufficientContributors) { try FoundationRulesMath.uncalledReturn(contributions: [20]) }
    #expect(throws: FoundationRulesMathError.invalidAmount) { try FoundationRulesMath.oddChipShares(pot: 10, winnerCount: 0) }
}

@Test func foundationRulesMathRejectsNonFiniteArithmeticResults() {
    let largest = Double.greatestFiniteMagnitude
    #expect(throws: FoundationRulesMathError.nonFiniteResult) {
        try FoundationRulesMath.spr(effectiveRemaining: largest, pot: .leastNonzeroMagnitude)
    }
    #expect(throws: FoundationRulesMathError.nonFiniteResult) {
        try FoundationRulesMath.potAfterBetAndCall(pot: largest, bet: largest)
    }
    #expect(throws: FoundationRulesMathError.nonFiniteResult) {
        try FoundationRulesMath.minimumRaiseTo(currentBet: largest, lastFullRaise: largest)
    }
    #expect(throws: FoundationRulesMathError.nonFiniteResult) {
        try FoundationRulesMath.potLayer(lower: 0, upper: largest, contributions: [largest, largest])
    }
}

@Test func foundationRuleAnswersAcceptOnlyExpectedTypedResponses() throws {
    let spr = try #require(FoundationLesson.exercise(.init(rawValue: "E.foundation.T03.spr")))
    #expect(spr.answer.accepts(.number(4)))
    #expect(!spr.answer.accepts(.number(4.1)))

    let bba = try #require(FoundationLesson.exercise(.init(rawValue: "E.foundation.T03.bba")))
    #expect(bba.answer.accepts(.choice(1)))
    #expect(!bba.answer.accepts(.choice(0)))

    let oddChip = try #require(FoundationLesson.exercise(.init(rawValue: "E.foundation.T05.odd-chip")))
    #expect(oddChip.answer.accepts(.number(51)))
    #expect(!oddChip.answer.accepts(.number(50)))
}
