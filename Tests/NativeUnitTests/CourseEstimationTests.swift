import Foundation
import Testing
@testable import PokerCore

@Test func monteCarloMatchesExactEquityWithinReportedSamplingError() throws {
    let question = KnownHandEquityQuestion.examples[0]
    let exact = try question.calculate()
    let report = try CourseMonteCarlo.sample(question, samples: 20_000, seed: 20_261_021)
    #expect(report.samples == 20_000)
    #expect(report.wins + report.ties + report.losses == 20_000)
    #expect(abs(report.meanPercent - exact.equityPercent) < 4 * report.standardErrorPP)
    #expect(report.lower95Percent < report.meanPercent && report.meanPercent < report.upper95Percent)
}

@Test func monteCarloIsSeedStableAndUsesHalfBankForTies() throws {
    let tie = KnownHandEquityQuestion.examples[1]
    let first = try CourseMonteCarlo.sample(tie, samples: 2_000, seed: 7)
    let second = try CourseMonteCarlo.sample(tie, samples: 2_000, seed: 7)
    #expect(first == second)
    #expect(first.wins == 0 && first.ties == 2_000 && first.losses == 0)
    #expect(first.meanPercent == 50)
    #expect(first.standardErrorPP == 0)
}

@Test func monteCarloReportUsesUnbiasedVarianceAndRejectsInvalidCounts() throws {
    let report = try CourseMonteCarloReport(seed: 1, wins: 1, ties: 1, losses: 2)
    let values = [1.0, 0.5, 0.0, 0.0]
    let mean = values.reduce(0, +) / Double(values.count)
    let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
    #expect(abs(report.meanPercent - 37.5) < 0.000_000_1)
    #expect(abs(report.standardErrorPP - 100 * sqrt(variance / 4)) < 0.000_000_1)
    #expect(throws: CourseMonteCarloError.invalidReportCounts) {
        try CourseMonteCarloReport(seed: 1, wins: 1, ties: 0, losses: 0)
    }
    #expect(throws: CourseMonteCarloError.invalidSampleCount) {
        try CourseMonteCarlo.sample(KnownHandEquityQuestion.examples[0], samples: 1, seed: 1)
    }
}

@Test func estimationExercisesCoverAllPurposesAndKeepTypedKeys() {
    let expected: Set<CourseTopicID> = [.t10, .t14, .t15, .t16]
    #expect(FoundationLesson.estimationExercises.count == 12)
    #expect(Set(FoundationLesson.estimationExercises.map(\.topicID)) == expected)
    for topic in expected {
        let exercises = FoundationLesson.estimationExercises.filter { $0.topicID == topic }
        #expect(Set(exercises.map(\.purpose)) == Set(FoundationPurpose.allCases))
        #expect(exercises.allSatisfy { !$0.context.isEmpty && !$0.question.isEmpty && !$0.explanation.isEmpty })
        #expect(exercises.allSatisfy { $0.answer.accepts($0.answer.correctResponse) })
        #expect(exercises.allSatisfy { $0.researchAnchor == "nlhe-complete-knowledge-map.md#\($0.topicID.rawValue.lowercased())" })
    }
}
