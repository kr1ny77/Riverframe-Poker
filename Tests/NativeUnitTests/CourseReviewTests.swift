import Testing
@testable import PokerCore

@Test func reviewLessonsCoverSatelliteAndReviewTopicsWithThreePurposes() {
    let topics: Set<CourseTopicID> = [.t48, .t52, .t53, .t54, .t60]
    let tasks = FoundationLesson.reviewExercises
    #expect(tasks.count == 15)
    #expect(Set(tasks.map(\.id)).count == tasks.count)
    #expect(Set(tasks.map(\.topicID)) == topics)
    for topic in topics {
        let group = tasks.filter { $0.topicID == topic }
        #expect(Set(group.map(\.purpose)) == Set(FoundationPurpose.allCases))
        #expect(group.allSatisfy { !$0.context.isEmpty && !$0.explanation.isEmpty && !$0.diagram.isEmpty })
        #expect(group.allSatisfy { $0.answer.accepts($0.answer.correctResponse) })
    }
}

@Test func satellitePassportUsesAllStacksAndSeparateTicketLeaves() throws {
    let fold = try CourseICM.prizeEquities(stacks: [50, 29, 21], payouts: [1, 1, 0])[1]
    let win = try CourseICM.prizeEquities(stacks: [50, 50, 0], payouts: [1, 1, 0])[1]
    let lose = try CourseICM.prizeEquities(stacks: [50, 10, 40], payouts: [1, 1, 0])[1]
    #expect(abs(fold - 0.6570886075949367) < 1e-12)
    #expect(abs(win - 1) < 1e-12)
    #expect(abs(lose - 0.26666666666666666) < 1e-12)
    let call = try CourseICM.weightedPrizeEV(probabilities: [0.7, 0.3], prizes: [win, lose])
    #expect(abs(call - 0.78) < 1e-12 && call > fold)
}

@Test func reviewMathAndDecisionTimeBoundariesStayExplicit() {
    #expect(CourseReviewMath.callEV(equity: 0.25, finalPot: 42, call: 11) == -0.5)
    #expect(CourseReviewMath.callEV(equity: 0.25, finalPot: 150, call: 30) == 7.5)
    #expect(CourseReviewMath.callEV(equity: 1.1, finalPot: 150, call: 30) == nil)
    #expect(CourseReviewMath.winRatePercent(wins: 14, observations: 20) == 70)
    #expect(CourseReviewMath.winRatePercent(wins: 21, observations: 20) == nil)
    let boundary = FoundationLesson.reviewExercises.first { $0.id.rawValue == "E.foundation.t52.missing-range" }
    #expect(boundary?.answer.accepts(.choice(1)) == true)
}

@Test func reviewNumericKeysAndPhysicalCardRemovalMatchIndependentArithmetic() {
    let expected: [String: Double] = [
        "t48.ticket-fold": 0.6570886075949367,
        "t48.ticket-call": 0.78,
        "t52.counterfactual-ev": -0.5,
        "t53.price-error": 25,
        "t60.audit-price": 7.5
    ]
    for (suffix, value) in expected {
        let task = FoundationLesson.reviewExercises.first { $0.id.rawValue.hasSuffix(suffix) }
        guard case .number(let actual, _) = task?.answer else {
            Issue.record("Missing numeric key \(suffix)")
            continue
        }
        #expect(abs(actual - value) < 1e-12)
    }

    let hero = Set([Card(id: 12), Card(id: 25)]) // A♠ A♥
    let impossible = Set([Card(id: 12), Card(id: 38)]) // A♠ A♦
    let allowed = Set([Card(id: 38), Card(id: 51)]) // A♦ A♣
    #expect(!hero.isDisjoint(with: impossible))
    #expect(hero.isDisjoint(with: allowed))
    let remainingAces = (0..<52).map(Card.init(id:)).filter { $0.rank == 14 && !hero.contains($0) }
    #expect(remainingAces == [Card(id: 38), Card(id: 51)])
}
