import Foundation
import Testing
@testable import PokerCore

@Test func icmMatchesIndependentThreePlayerClosedFormForR0() throws {
    let fold = try CourseICM.prizeEquities(stacks: [48, 30, 22], payouts: [50, 30, 20])
    // B: 30/100 first; 48/100×30/52 + 22/100×30/78 second; remaining third.
    let bSecond = 48.0 / 100 * 30 / 52 + 22.0 / 100 * 30 / 78
    let bThird = 1 - 30.0 / 100 - bSecond
    let independent = 50 * 30.0 / 100 + 30 * bSecond + 20 * bThird
    #expect(abs(fold[1] - independent) < 1e-10)
    #expect(abs(fold[1] - 32.61538461538461) < 1e-10)
    let win = try CourseICM.prizeEquities(stacks: [48, 52, 0], payouts: [50, 30, 20])
    let lose = try CourseICM.prizeEquities(stacks: [48, 10, 42], payouts: [50, 30, 20])
    #expect(abs(win[1] - 40.4) < 1e-10)
    #expect(abs(lose[1] - 24.647214854111405) < 1e-10)
    #expect(abs(try CourseICM.callThresholdPercent(fold: fold[1], win: win[1], lose: lose[1]) - 50.5826093) < 1e-5)
}

@Test func icmConservesPayoutsAndRespectsScaleAndPermutationSymmetry() throws {
    let payouts = [50.0, 30, 20]
    let values = try CourseICM.prizeEquities(stacks: [40, 30, 30], payouts: payouts)
    #expect(abs(values.reduce(0, +) - payouts.reduce(0, +)) < 1e-10)
    #expect(abs(values[1] - values[2]) < 1e-10)
    let scaled = try CourseICM.prizeEquities(stacks: [400, 300, 300], payouts: payouts)
    for index in values.indices { #expect(abs(values[index] - scaled[index]) < 1e-10) }
    let permuted = try CourseICM.prizeEquities(stacks: [30, 40, 30], payouts: payouts)
    #expect(abs(permuted[0] - values[1]) < 1e-10)
    #expect(abs(permuted[1] - values[0]) < 1e-10)
}

@Test func icmSupportsEqualPayoutsAndOneEliminatedPlayer() throws {
    let equal = try CourseICM.prizeEquities(stacks: [1, 2, 3], payouts: [10, 10, 10])
    #expect(equal == [10, 10, 10])
    let wta = try CourseICM.prizeEquities(stacks: [50, 50, 0], payouts: [100, 0, 0])
    #expect(abs(wta[0] - 50) < 1e-10 && abs(wta[1] - 50) < 1e-10 && wta[2] == 0)
    let paidElimination = try CourseICM.prizeEquities(stacks: [50, 50, 0], payouts: [50, 30, 20])
    #expect(paidElimination[2] == 20)
    #expect(throws: CourseICMError.multipleEliminationsNeedPlacementRule) {
        try CourseICM.prizeEquities(stacks: [100, 0, 0], payouts: [50, 30, 20])
    }
}

@Test func icmRejectsInvalidInputsAndChecksWTLDenominator() throws {
    #expect(throws: CourseICMError.invalidScenario) {
        try CourseICM.prizeEquities(stacks: [60, 40], payouts: [10, 20])
    }
    #expect(throws: CourseICMError.invalidScenario) {
        try CourseICM.prizeEquities(stacks: [Double.infinity, 1], payouts: [1, 0])
    }
    #expect(throws: CourseICMError.invalidScenario) {
        try CourseICM.prizeEquities(stacks: [1, 1, 1, 1, 1, 1, 1], payouts: [7, 6, 5, 4, 3, 2, 1])
    }
    #expect(throws: CourseICMError.invalidScenario) {
        try CourseICM.prizeEquities(stacks: [Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude], payouts: [1, 0])
    }
    #expect(throws: CourseICMError.invalidScenario) {
        try CourseICM.prizeEquities(stacks: [1, 1], payouts: [Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude])
    }
    #expect(throws: CourseICMError.invalidProbability) {
        try CourseICM.weightedPrizeEV(probabilities: [0.5, 0.4], prizes: [10, 0])
    }
    #expect(abs(try CourseICM.weightedPrizeEV(probabilities: [0.5, 0.1, 0.4], prizes: [40, 30, 20]) - 31) < 1e-10)
    #expect(abs(try CourseICM.pureShoveFoldThresholdPercent(risk: 10, reward: 2.5) - 80) < 1e-10)
    #expect(throws: CourseICMError.invalidScenario) {
        try CourseICM.pureShoveFoldThresholdPercent(risk: .greatestFiniteMagnitude, reward: .greatestFiniteMagnitude)
    }
    #expect(throws: CourseICMError.invalidScenario) {
        try CourseICM.bubbleFactor(fold: -Double.greatestFiniteMagnitude / 2, win: .greatestFiniteMagnitude, lose: -Double.greatestFiniteMagnitude)
    }
    #expect(throws: CourseICMError.invalidScenario) { try CourseICM.sidePots(contributions: [60, 100, 20]) }
    #expect(throws: CourseICMError.invalidScenario) {
        try CourseICM.sidePots(contributions: [.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude])
    }
}

@Test func icmSidePotAccountingKeepsAllChipsAndExercisesCoverFiveTopics() throws {
    let pots = try CourseICM.sidePots(contributions: [100, 60, 20])
    #expect(pots.main == 60 && pots.side == 80 && pots.refund == 40 && pots.total == 180)
    let tasks = FoundationLesson.icmExercises
    let topics: Set<CourseTopicID> = [.t45, .t46, .t47, .t49, .t50]
    #expect(tasks.count == 17)
    #expect(Set(tasks.map(\.id)).count == tasks.count)
    #expect(Set(tasks.map(\.topicID)) == topics)
    for topic in topics {
        let group = tasks.filter { $0.topicID == topic }
        #expect(group.count >= 3)
        #expect(Set(group.map(\.purpose)).isSuperset(of: Set(FoundationPurpose.allCases)))
        #expect(group.allSatisfy { $0.answer.accepts($0.answer.correctResponse) })
        #expect(group.allSatisfy { !$0.context.isEmpty && !$0.explanation.isEmpty && !$0.assumptions.isEmpty })
    }
    let sidePotICM = try #require(tasks.first { $0.id.rawValue == "E.foundation.t50.icm-after-leaf" })
    #expect(sidePotICM.answer.accepts(.number(85)))
    let independentSidePotICM = 150.0 / 180 * 90 + 30.0 / 180 * 60
    #expect(abs(independentSidePotICM - 85) < 1e-10)
    #expect(abs(try CourseICM.prizeEquities(stacks: [150, 0, 30], payouts: [90, 60, 30])[0] - independentSidePotICM) < 1e-10)
}
