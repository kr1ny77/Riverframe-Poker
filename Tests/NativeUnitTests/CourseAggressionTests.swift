import Foundation
import Testing
@testable import PokerCore

@Test func aggressionBatchHasThreePurposesPerTopicAndFullTeachingPassport() {
    let topics: Set<CourseTopicID> = [.t12, .t13, .t36, .t38, .t19, .t20]
    #expect(FoundationLesson.aggressionExercises.count == 19)
    #expect(Set(FoundationLesson.aggressionExercises.map(\.topicID)) == topics)

    for topic in topics {
        let exercises = FoundationLesson.aggressionExercises.filter { $0.topicID == topic }
        #expect(exercises.count == (topic == .t13 ? 4 : 3))
        #expect(Set(exercises.map(\.purpose)) == Set(FoundationPurpose.allCases))
        for exercise in exercises {
            #expect(!exercise.context.isEmpty)
            #expect(!exercise.explanation.isEmpty)
            #expect(!exercise.typicalError.isEmpty)
            #expect(!exercise.diagram.isEmpty)
            #expect([LessonResultKind.conditionalModel, .definitions, .exact].contains { $0.rawValue == exercise.resultKind.rawValue })
            #expect(exercise.researchAnchor == "nlhe-complete-knowledge-map.md#\(topic.rawValue.lowercased())")
            #expect(exercise.answer.accepts(exercise.answer.correctResponse))
        }
    }
}

@Test func aggressionEVTreesUseIndependentFoldCallAndStackInputs() throws {
    #expect(abs(try CourseAggressionMath.foldThresholdPercent(pot: 100, bet: 50) - 100.0 / 3) < 1e-10)
    #expect(try CourseAggressionMath.betEV(foldRate: 0.4, equityWhenCalled: 0.2, pot: 100, bet: 50) == 34)
    #expect(try CourseAggressionMath.shoveEV(foldRate: 0.3, equityWhenCalled: 0.45, pot: 120, risk: 60, finalContestedPot: 240) == 69.6)
    #expect(try CourseAggressionMath.shoveEV(foldRate: 0, equityWhenCalled: 0.45, pot: 120, risk: 40, finalContestedPot: 200) == 50)
    #expect(try CourseAggressionMath.shoveEV(foldRate: 0.3, equityWhenCalled: 0.4, pot: 140, risk: 100, finalContestedPot: 300) == 56)
    #expect(abs(try CourseAggressionMath.ratio(numerator: 12, denominator: 44) * 100 - 300.0 / 11) < 1e-10)
}

@Test func namedRiverHandsMatchTheDeclaredCallAndRemovalBranches() {
    let board = [Card(id: 36), Card(id: 44), Card(id: 15), Card(id: 0), Card(id: 33)] // Qd 7c 4h 2s 9d
    let firstHero = [Card(id: 48), Card(id: 47)] // Jc Tc
    #expect(HandEvaluator.best(of: firstHero + board) < HandEvaluator.best(of: [Card(id: 51), Card(id: 37)] + board)) // Ac Kd
    #expect(HandEvaluator.best(of: firstHero + board) < HandEvaluator.best(of: [Card(id: 23), Card(id: 10)] + board)) // Qh Qs

    let secondHero = [Card(id: 12), Card(id: 49)] // As Qc
    #expect(HandEvaluator.best(of: secondHero + board) < HandEvaluator.best(of: [Card(id: 23), Card(id: 10)] + board))
    #expect(HandEvaluator.best(of: secondHero + board) > HandEvaluator.best(of: [Card(id: 48), Card(id: 47)] + board))
    let removal = FoundationLesson.aggressionExercises.first { $0.id.rawValue == "E.foundation.t20.removal-transfer" }
    #expect(removal.map { Set($0.cards).count == $0.cards.count } == true)
    #expect(removal?.context.joined(separator: " ").contains("A♠K♦") == true)
}

@Test func mdfRatioFractionAndBluffCatcherUseTheirOwnDenominators() throws {
    #expect(abs(try CourseAggressionMath.mdfPercent(pot: 100, bet: 50) - 200.0 / 3) < 1e-10)
    #expect(abs(try CourseAggressionMath.bluffValueRatio(pot: 100, bet: 50) - 1.0 / 3) < 1e-10)
    #expect(try CourseAggressionMath.bluffFractionPercent(pot: 100, bet: 50) == 25)
    #expect(try CourseAggressionMath.bluffCatcherEV(bluffShare: 0.3, potBeforeBet: 100, call: 50) == 10)
    #expect(try CourseAggressionMath.bluffCatcherEV(bluffShare: 0.25, potBeforeBet: 100, call: 50) == 0)
    #expect(try CourseAggressionMath.ratio(numerator: 4, denominator: 10) * 100 == 40)
}

@Test func aggressionMathRejectsInvalidAndOverflowingInputs() {
    #expect(throws: (any Error).self) { try CourseAggressionMath.foldThresholdPercent(pot: 100, bet: 0) }
    #expect(throws: (any Error).self) { try CourseAggressionMath.betEV(foldRate: 1.1, equityWhenCalled: 0.2, pot: 100, bet: 50) }
    #expect(throws: (any Error).self) { try CourseAggressionMath.shoveEV(foldRate: 0.2, equityWhenCalled: 0.5, pot: 100, risk: 250, finalContestedPot: 200) }
    #expect(throws: (any Error).self) { try CourseAggressionMath.mdfPercent(pot: .greatestFiniteMagnitude, bet: .greatestFiniteMagnitude) }
    #expect(throws: (any Error).self) { try CourseAggressionMath.bluffCatcherEV(bluffShare: .nan, potBeforeBet: 100, call: 50) }
    #expect(throws: (any Error).self) { try CourseAggressionMath.ratio(numerator: 1, denominator: 0) }
}
