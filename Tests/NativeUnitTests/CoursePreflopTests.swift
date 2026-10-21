import Foundation
import Testing
@testable import PokerCore

@Test func preflopExercisesCoverThreePurposesForEveryPreflopTopic() {
    let expected: Set<CourseTopicID> = [.t23, .t24, .t25, .t26, .t27]
    #expect(FoundationLesson.preflopExercises.count == 15)
    #expect(Set(FoundationLesson.preflopExercises.map(\.id)).count == 15)
    #expect(Set(FoundationLesson.preflopExercises.map(\.topicID)) == expected)
    for topic in expected {
        let exercises = FoundationLesson.preflopExercises.filter { $0.topicID == topic }
        #expect(exercises.count == 3)
        #expect(Set(exercises.map(\.purpose)) == Set(FoundationPurpose.allCases))
        #expect(exercises.allSatisfy { !$0.context.isEmpty && !$0.question.isEmpty && !$0.explanation.isEmpty && !$0.typicalError.isEmpty })
        #expect(exercises.allSatisfy { !$0.term.isEmpty && !$0.definition.isEmpty && !$0.example.isEmpty && !$0.method.isEmpty && !$0.assumptions.isEmpty })
        #expect(exercises.allSatisfy { $0.researchAnchor == "nlhe-complete-knowledge-map.md#\(topic.rawValue.lowercased())" })
        #expect(exercises.allSatisfy { $0.answer.accepts($0.answer.correctResponse) })
    }
}

@Test func preflopMathMatchesIndependentResearchConstants() throws {
    #expect(abs(try CoursePreflopMath.allInThresholdPercent(call: 1.5, potBeforeCall: 4) - (100 * 3 / 11)) < 1e-10)
    #expect(abs(try CoursePreflopMath.allInThresholdPercent(call: 2, potBeforeCall: 4.5) - (100 * 4 / 13)) < 1e-10)
    #expect(abs(try CoursePreflopMath.allInThresholdPercent(call: 4, potBeforeCall: 7.5) - (100 * 8 / 23)) < 1e-10)
    #expect(abs(try CoursePreflopMath.allInThresholdPercent(call: 5, potBeforeCall: 11.5) - (100 * 10 / 33)) < 1e-10)
    #expect(abs(try CoursePreflopMath.allInThresholdPercent(call: 8.5, potBeforeCall: 17) - (100 / 3)) < 1e-10)
    #expect(try CoursePreflopMath.additionalContribution(to: 300, alreadyContributed: 10) == 290)
    #expect(try CoursePreflopMath.finalPot(contributions: [12, 20, 300, 300]) == 632)
    #expect(abs(try CoursePreflopMath.allInThresholdPercent(call: 290, potBeforeCall: 87) - (1000 / 13)) < 1e-10)
}

@Test func preflopMathRejectsInvalidAndOverflowingInputs() {
    #expect(throws: CoursePreflopMathError.invalidAmount) { try CoursePreflopMath.allInThresholdPercent(call: 0, potBeforeCall: 0) }
    #expect(throws: CoursePreflopMathError.invalidAmount) { try CoursePreflopMath.additionalContribution(to: 4, alreadyContributed: 5) }
    #expect(throws: CoursePreflopMathError.invalidAmount) { try CoursePreflopMath.finalPot(contributions: []) }
    #expect(throws: CoursePreflopMathError.invalidAmount) { try CoursePreflopMath.finalPot(contributions: [.nan]) }
    #expect(throws: CoursePreflopMathError.nonFiniteResult) { try CoursePreflopMath.finalPot(contributions: [.greatestFiniteMagnitude, .greatestFiniteMagnitude]) }
    #expect(throws: CoursePreflopMathError.nonFiniteResult) { try CoursePreflopMath.allInThresholdPercent(call: .greatestFiniteMagnitude, potBeforeCall: .greatestFiniteMagnitude) }
}

@Test func preflopTypedAnswersMatchPublishedPassportExamples() throws {
    let checks: [(String, FoundationResponse)] = [
        ("E.foundation.t23.bb-price", .number(100 * 3 / 11)),
        ("E.foundation.t24.limper-price", .number(100 * 8 / 23)),
        ("E.foundation.t25.bet-names", .choice(0)),
        ("E.foundation.t26.btn-squeeze-price", .number(100 / 3)),
        ("E.foundation.t27.final-pot", .number(632))
    ]
    for (id, response) in checks {
        let exercise = try #require(FoundationLesson.preflopExercises.first { $0.id.rawValue == id })
        #expect(exercise.answer.accepts(response))
        #expect(FoundationAttempt(exercise: exercise, response: response).isValid)
    }
    let t27 = try #require(FoundationLesson.preflopExercises.first { $0.id.rawValue == "E.foundation.t27.icm-limit" })
    #expect(t27.answer.accepts(.choice(1)))
    #expect(!t27.answer.accepts(.choice(0)))
}
