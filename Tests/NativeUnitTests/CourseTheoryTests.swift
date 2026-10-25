import Testing
@testable import PokerCore

@Test func theoryLessonsCoverM14AndM15WithTypedAnswers() {
    let topics: Set<CourseTopicID> = [.t41, .t42, .t43, .t44, .t51]
    let tasks = FoundationLesson.theoryExercises
    #expect(tasks.count == 15)
    #expect(Set(tasks.map(\.id)).count == 15)
    #expect(Set(tasks.map(\.topicID)) == topics)
    for topic in topics {
        let group = tasks.filter { $0.topicID == topic }
        #expect(Set(group.map(\.purpose)) == Set(FoundationPurpose.allCases))
        #expect(group.allSatisfy { !$0.context.isEmpty && !$0.explanation.isEmpty && !$0.assumptions.isEmpty })
        #expect(group.allSatisfy { $0.answer.accepts($0.answer.correctResponse) })
        #expect(group.allSatisfy { !$0.researchAnchor.isEmpty && $0.diagram.count == 2 })
    }
}

@Test func mixedEVAndSimplificationUseIndependentWeightedArithmetic() throws {
    let value = try CourseTheoryMath.mixedEV(probabilities: [0.25, 0.75], actionEVs: [8, 7])
    let independent = 8.0 / 4 + 7.0 * 3 / 4
    #expect(abs(value - independent) < 1e-12)
    #expect(abs(try CourseTheoryMath.loss(fromBest: value, simplifiedEV: 7) - 0.25) < 1e-12)
    #expect(CourseTheoryMath.frequenciesAreNormalized([0.3, 0.5, 0.2]))
    #expect(!CourseTheoryMath.frequenciesAreNormalized([0.3, 0.5, 0.1]))
}

@Test func matchingPenniesAndFixedSuitRangesHaveTheDocumentedBoundaries() throws {
    // Independent payoff calculation: each pure A action wins once and loses once against B's 50/50 policy.
    let left = try CourseTheoryMath.mixedEV(probabilities: [0.5, 0.5], actionEVs: [1, -1])
    let right = try CourseTheoryMath.mixedEV(probabilities: [0.5, 0.5], actionEVs: [-1, 1])
    #expect(left == 0 && right == 0)

    let boardA = [Card(id: 10), Card(id: 31), Card(id: 39)] // Q♠ 7♦ 2♣
    let boardB = [Card(id: 23), Card(id: 31), Card(id: 39)] // Q♥ 7♦ 2♣
    let rangeA = [Card(id: 10), Card(id: 3)] // Q♠ 5♠
    let rangeB = [Card(id: 23), Card(id: 16)] // Q♥ 5♥
    #expect(Set(boardA).isDisjoint(with: Set(rangeB)))
    #expect(!Set(boardA).isDisjoint(with: Set(rangeA)))
    #expect(Set(boardB).isDisjoint(with: Set(rangeA)))
    #expect(!Set(boardB).isDisjoint(with: Set(rangeB)))
}

@Test func observationRatesSeparateArithmeticFromUncertainty() throws {
    #expect(try CourseTheoryMath.sampleRate(successes: 2, trials: 2) == 1)
    let interval = try CourseTheoryMath.wilson95(successes: 140, trials: 200)
    #expect(abs(interval.lowerBound - 0.633) < 0.002)
    #expect(abs(interval.upperBound - 0.759) < 0.002)
    #expect(interval.contains(0.7))
}

@Test func theoryMathRejectsBrokenModels() {
    #expect(throws: CourseTheoryMathError.invalidInput) {
        try CourseTheoryMath.mixedEV(probabilities: [0.4, 0.4], actionEVs: [1, 2])
    }
    #expect(throws: CourseTheoryMathError.invalidInput) {
        try CourseTheoryMath.mixedEV(probabilities: [1], actionEVs: [.infinity])
    }
    #expect(throws: CourseTheoryMathError.invalidInput) { try CourseTheoryMath.sampleRate(successes: 3, trials: 2) }
    #expect(throws: CourseTheoryMathError.invalidInput) { try CourseTheoryMath.sampleRate(successes: 0.5, trials: 2) }
    #expect(throws: CourseTheoryMathError.invalidInput) { try CourseTheoryMath.wilson95(successes: 0, trials: 0.5) }
    #expect(throws: CourseTheoryMathError.invalidInput) { try CourseTheoryMath.wilson95(successes: 0, trials: 0) }
}
