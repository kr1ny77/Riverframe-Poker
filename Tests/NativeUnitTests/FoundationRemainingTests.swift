import Foundation
import Testing
@testable import PokerCore

@Test func foundationRemainingHasThreePurposesForEveryCoveredTopic() {
    let topics: Set<CourseTopicID> = [.t06, .t07, .t08, .t09, .t21, .t22, .t28]
    let expectedCounts: [CourseTopicID: Int] = [.t06: 3, .t07: 3, .t08: 3, .t09: 3, .t21: 3, .t22: 4, .t28: 3]
    #expect(FoundationLesson.remainingExercises.count == 22)
    #expect(Set(FoundationLesson.remainingExercises.map(\.id)).count == 22)
    for topic in topics {
        let exercises = FoundationLesson.remainingExercises.filter { $0.topicID == topic }
        #expect(exercises.count == expectedCounts[topic]!)
        #expect(Set(exercises.map(\.purpose)) == Set(FoundationPurpose.allCases))
        #expect(exercises.allSatisfy { !$0.context.isEmpty && !$0.question.isEmpty && !$0.explanation.isEmpty && !$0.typicalError.isEmpty })
        #expect(exercises.allSatisfy { !$0.term.isEmpty && !$0.definition.isEmpty && !$0.example.isEmpty && !$0.method.isEmpty && !$0.assumptions.isEmpty })
        #expect(exercises.allSatisfy { $0.researchAnchor == "nlhe-complete-knowledge-map.md#\(topic.rawValue.lowercased())" })
    }
}

@Test func t22ChartCarriesItsPassportAndGradesTheDisplayedMark() throws {
    let exercise = try #require(FoundationLesson.remainingExercises.first { $0.id.rawValue == "E.foundation.t22.chart-co-read" })
    #expect(exercise.purpose == .transfer)
    #expect(exercise.resultKind == .conditionalModel)
    #expect(exercise.chart.map(\.label) == ["AA", "KK", "QQ", "AKs", "AQo", "KQs"])
    #expect(exercise.chart.allSatisfy { $0.value == "Открыть" })
    #expect(exercise.context.joined(separator: " ").contains("100 BB"))
    #expect(exercise.context.joined(separator: " ").contains("рейк 0"))
    #expect(exercise.answer.accepts(.choice(0)))
    #expect(!exercise.answer.accepts(.choice(1)))
}

@Test func foundationStudyMathMatchesIndependentResearchConstants() {
    #expect(abs(FoundationStudyMath.exactlyOneAceByRiverPercent - 100 * 132.0 / 1081) < 0.000_000_1)
    #expect(abs(FoundationStudyMath.dirtyOutEquityPercent - 100 * 7.0 / 44) < 0.000_000_1)
    #expect(abs(FoundationStudyMath.equityPercent(wins: 10, ties: 4, total: 44) - 100 * 12.0 / 44) < 0.000_000_1)
    #expect(abs(FoundationStudyMath.weightedEquityPercent(firstEquity: 30, firstWeight: 1, secondEquity: 70, secondWeight: 2) - 170.0 / 3) < 0.000_000_1)
}

@Test func foundationAnswersAcceptOnlyTheirTypedExpectedResponses() {
    for exercise in FoundationLesson.remainingExercises {
        #expect(exercise.answer.accepts(exercise.answer.correctResponse))
        switch exercise.answer {
        case .number(let value, _):
            #expect(!exercise.answer.accepts(.number(value + 1)))
            #expect(!exercise.answer.accepts(.choice(0)))
        case .choice(let options, let correct):
            let wrong = options.indices.first { $0 != correct }!
            #expect(!exercise.answer.accepts(.choice(wrong)))
            #expect(!exercise.answer.accepts(.number(Double(correct))))
        }
    }
}

@Test func dirtyOutExampleAgreesWithTheExistingExactEvaluator() throws {
    let question = try KnownHandEquityQuestion(
        id: "dirty-outs-reference",
        hero: [Card(id: 12), Card(id: 9)],
        opponent: [Card(id: 37), Card(id: 50)],
        board: [Card(id: 11), Card(id: 31), Card(id: 0), Card(id: 15)]
    )
    let result = try question.calculate()
    #expect(result.wins == FoundationStudyMath.dirtyOutsClean)
    #expect(result.ties == 0)
    #expect(result.losses == 37)
    #expect(result.total == FoundationStudyMath.dirtyOutsTotalRiver)
    #expect(abs(result.equityPercent - FoundationStudyMath.dirtyOutEquityPercent) < 0.000_000_1)
}

@Test func foundationAttemptPreservesTypedAnswerAndResult() {
    let exercise = FoundationLesson.remainingExercises.first { $0.id.rawValue == "E.foundation.t09.weighted-equity" }!
    let exact = FoundationAttempt(exercise: exercise, response: exercise.answer.correctResponse,
                                  id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, date: Date(timeIntervalSinceReferenceDate: 20_000))
    let wrong = FoundationAttempt(exercise: exercise, response: .number(0))
    #expect(exact.isCorrect && exact.isValid)
    #expect(!wrong.isCorrect && wrong.isValid)
    #expect(exact.expected == .number(70))
}

@Test func t28BoundaryKeepsPokerModelContextForFormatTransfer() throws {
    let exercise = try #require(FoundationLesson.remainingExercises.first { $0.id.rawValue == "E.foundation.t28.table-limit" })
    #expect(exercise.purpose == .boundary)
    #expect(exercise.resultKind == .conditionalModel)
    #expect(exercise.context.joined(separator: " ").contains("восемь игроков"))
    #expect(exercise.context.joined(separator: " ").contains("пять игроков"))
    #expect(exercise.answer.accepts(.choice(1)))
    #expect(!exercise.answer.accepts(.choice(0)))
}

@Test func weightedTransferUsesPhysicalResearchBranchesWithChangedWeights() throws {
    let exercise = try #require(FoundationLesson.exercise(.init(rawValue: "E.foundation.t09.weighted-equity")))
    #expect(exercise.answer.accepts(.number(70)))
    #expect(!exercise.answer.accepts(.number(75)))
    let hero = [Card(id: 12), Card(id: 24)] // As Kh
    let board = [Card(id: 8), Card(id: 22), Card(id: 36), Card(id: 39)] // Ts Jh Qd 2c
    let tie = try KnownHandEquityQuestion(id: "research-weight-tie", hero: hero,
        opponent: [Card(id: 38), Card(id: 50)], board: board).calculate() // Ad Kc
    let win = try KnownHandEquityQuestion(id: "research-weight-win", hero: hero,
        opponent: [Card(id: 7), Card(id: 20)], board: board).calculate() // 9s 9h
    #expect(tie.ties == 44 && win.wins == 44)
    let expected = (3 * tie.equityPercent + 2 * win.equityPercent) / 5
    #expect(expected == 70)
    #expect(exercise.answer.accepts(.number(expected)))
}
