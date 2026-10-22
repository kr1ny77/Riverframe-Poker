import Foundation
import Testing
@testable import PokerCore

private let advancedTopics: Set<CourseTopicID> = [.t12, .t13, .t36, .t38, .t30, .t31, .t33, .t40, .t19, .t20, .t45, .t46, .t47, .t49, .t50]

@Test func advancedCatalogHasStableIDsThreePurposesAndDisclosedModels() {
    let tasks = FoundationLesson.advancedExercises
    #expect(tasks.count == 49)
    #expect(Set(tasks.map(\.id)).count == tasks.count)
    #expect(Set(tasks.map(\.topicID)) == advancedTopics)
    #expect(CourseCatalog.contentVersion == 4)
    #expect(CourseCatalog.allExerciseIDs.count == 181)
    let previous = FoundationLesson.v2Exercises + FoundationLesson.intermediateExercises
    #expect(Set(tasks.map(\.id)).isDisjoint(with: Set(previous.map(\.id))))
    for topic in advancedTopics {
        let group = CourseCatalog.foundations(for: topic)
        #expect(group.count >= 3)
        #expect(Set(group.map(\.purpose)) == Set(FoundationPurpose.allCases))
        for task in group {
            #expect(task.contentVersion == 1)
            #expect(!task.context.isEmpty && !task.explanation.isEmpty && !task.assumptions.isEmpty)
            #expect(!task.diagram.isEmpty && !task.term.isEmpty && !task.method.isEmpty && !task.typicalError.isEmpty)
            #expect(task.researchAnchor.hasSuffix(topic.rawValue.lowercased()))
            #expect(task.resultKind != .verifiedTable && task.resultKind != .monteCarlo)
            #expect(FoundationAttempt(exercise: task, response: task.answer.correctResponse).isValid)
            let wrong: FoundationResponse
            switch task.answer {
            case .number(let value, let tolerance): wrong = .number(value + max(1, tolerance * 2))
            case .choice(let options, let correct): wrong = .choice((correct + 1) % options.count)
            }
            #expect(!task.answer.accepts(wrong))
            #expect(FoundationAttempt(exercise: task, response: wrong).isValid)
            #expect(Set(task.cards).count == task.cards.count)
        }
    }
    // Shared M08 content stays one source; new topics link to it through prerequisites.
    #expect(CourseCatalog.foundations(for: .t32).count == 4)
    #expect(CourseCatalog.exercises(for: .t18).count == 6)
}

@Test func baselineV3All132ResultsSurviveAdvancedWritesAndRelaunch() throws {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/course-v3-all132.json")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Advanced-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let target = directory.appendingPathComponent("history.json")
    let bytes = try Data(contentsOf: fixture)
    try bytes.write(to: target)
    let history = PracticeHistory(fileURL: target)
    let baseline = try history.loadArchive()
    #expect(try Data(contentsOf: target) == bytes)
    #expect(baseline.foundations.count == 89)
    let previous = LearningCourseSnapshot(archive: baseline)
    #expect(previous.observations.count == 43 && previous.completedLessons == 8)
    #expect(CourseCatalogSnapshot(course: previous, foundations: baseline.foundations).overallProgress.covered == 132)
    var next = baseline
    next.foundations += FoundationLesson.advancedExercises.enumerated().map { index, task in
        FoundationAttempt(exercise: task, response: task.answer.correctResponse,
                          date: Date(timeIntervalSinceReferenceDate: 200_000 + Double(index)))
    }
    try history.saveArchive(next)
    let restored = try PracticeHistory(fileURL: target).loadArchive()
    #expect(restored == next)
    #expect(restored.attempts == baseline.attempts && restored.comparisons == baseline.comparisons)
    #expect(restored.positions == baseline.positions && restored.evCalls == baseline.evCalls && restored.blockers == baseline.blockers)
    #expect(Array(restored.foundations.prefix(89)) == baseline.foundations)
    #expect(LearningCourseSnapshot(archive: restored).completedLessons == 8)
    let snapshot = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: restored), foundations: restored.foundations)
    #expect(snapshot.overallProgress.covered == 181 && snapshot.ignoredRecords == 0)
    for topic in advancedTopics { #expect(snapshot.progress(for: topic).completedAvailableExercises) }
}

@Test func riverToyDenominatorsStayDistinctAndBoundaryCallsMatchEV() throws {
    let defense = try CourseAggressionMath.mdfPercent(pot: 100, bet: 50)
    let ratio = try CourseAggressionMath.bluffValueRatio(pot: 100, bet: 50)
    let share = try CourseAggressionMath.bluffFractionPercent(pot: 100, bet: 50)
    #expect(abs(defense - 200.0 / 3) < 1e-10)
    #expect(abs(ratio - 1.0 / 3) < 1e-10)
    #expect(abs(share - 25) < 1e-10)
    #expect(try CourseAggressionMath.bluffCatcherEV(bluffShare: 0.25, potBeforeBet: 100, call: 50) == 0)
    #expect(try CourseAggressionMath.bluffCatcherEV(bluffShare: 0.2, potBeforeBet: 100, call: 50) == -10)
    #expect(try CourseAggressionMath.betEV(foldRate: 0.4, equityWhenCalled: 0, pot: 100, bet: 50) == 10)
    #expect(abs(try CourseAggressionMath.betEV(foldRate: 0.4, equityWhenCalled: 0.2, pot: 100, bet: 50) - 34) < 1e-10)
}


@Test func advancedICMMatchesIndependentExactFractionOracleForAllLeavesAndSixPlayers() throws {
    struct Oracle: Decodable { let id: String; let stacks: [Double]; let payouts: [Double]; let expected: [Double] }
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/course-v4-math-oracle.json")
    let cases = try JSONDecoder().decode([Oracle].self, from: Data(contentsOf: url))
    #expect(cases.count == 10)
    for example in cases {
        let actual = try CourseICM.prizeEquities(stacks: example.stacks, payouts: example.payouts)
        for index in actual.indices { #expect(abs(actual[index] - example.expected[index]) < 1e-10, "\(example.id) seat\(index)") }
    }
    let tie = try CourseICM.prizeEquities(stacks: [48, 31, 21], payouts: [50, 30, 20])[1]
    let tieSecond = 48.0/100 * 31/52 + 21.0/100 * 31/79
    #expect(abs(tie - (0.31*50 + tieSecond*30 + (1-0.31-tieSecond)*20)) < 1e-10)
    let moneyEV = try CourseICM.weightedPrizeEV(probabilities: [0.45, 0.10, 0.45], prizes: [40.4, tie, 24.647214854111407])
    #expect(abs(moneyEV - (0.45*40.4 + 0.10*tie + 0.45*24.647214854111407)) < 1e-10)
    let small = try CourseICM.prizeEquities(stacks: Array(repeating: Double.leastNonzeroMagnitude, count: 6), payouts: [6,5,4,3,2,1])
    #expect(small.allSatisfy { abs($0 - 3.5) < 1e-10 })
}

@Test func advancedPhysicalCombinationCountsUseIndependentPairEnumeration() {
    func count(_ ranks: Set<Int>, suited: Bool?, board: [Card]) -> Int {
        let deck = (0..<52).map(Card.init(id:)).filter { !board.contains($0) }
        var result = 0
        for first in deck.indices {
            for second in deck.indices where second > first {
                let a = deck[first], b = deck[second]
                if Set([a.rank, b.rank]) == ranks && (suited == nil || (a.suit == b.suit) == suited!) { result += 1 }
            }
        }
        return result
    }
    let k72 = [Card(id: 11), Card(id: 31), Card(id: 39)]
    #expect(count([13], suited: nil, board: k72) == 3)
    #expect(count([14,13], suited: nil, board: k72) == 12)
    let low = [Card(id: 4), Card(id: 42), Card(id: 2)]
    #expect(count([7,6], suited: true, board: low) == 3)
    #expect(count([6,5], suited: true, board: low) == 2)
    #expect(count([5,4], suited: true, board: low) == 2)
    #expect(count([3], suited: nil, board: low) == 6)
    #expect(count([2], suited: nil, board: low) == 6)
    let river = [Card(id: 36),Card(id: 44),Card(id: 15),Card(id: 0),Card(id: 33)]
    #expect(HandEvaluator.best(of: [Card(id: 12),Card(id: 49)] + river) == HandEvaluator.best(of: [Card(id: 51),Card(id: 23)] + river))
}

@Test func advancedPublishedNumericKeysMatchIndependentWorkedExamples() throws {
    // Keys are independently derived in research passports and the Fraction oracle.
    let expected: [String: Double] = [
        "t12.fold-threshold": 100.0/3, "t12.semi-bluff-tree": 34,
        "t13.shove-tree": 69.6, "t13.short-cover": 50, "t13.raise-facing-bet": 56,
        "t36.call-price": 300.0/11, "t36.raise-fold-threshold": 50,
        "t38.flop-spr": 4, "t38.turn-overbet": 130,
        "t19.mdf-half-pot": 200.0/3, "t19.bluff-mass": 4,
        "t20.call-ev": 10, "t20.removal-transfer": 40,
        "t30.nut-mass": 3, "t30.weighted-tail": 6, "t30.river-range-contrast": 75,
        "t31.future-net-eqr": 75, "t31.above-hundred": 120,
        "t33.bb-coverage": 19, "t33.weighted-coverage": 7.5, "t40.accessible-price": 20,
        "t45.r0-fold": 32.61538461538461, "t45.r0-call-50": 32.5236074270557,
        "t46.bubble-factor": 1.023579119531143, "t46.threshold": 50.5826093, "t46.r0-risk-premium": 2.9635617,
        "t47.r1-fold": 17.26101694915254, "t47.r1-call-60": 18.6,
        "t49.fold-threshold": 80, "t50.accounting": 180, "t50.split-leaves": 150,
        "t50.icm-after-leaf": 85
    ]
    let numericTasks = FoundationLesson.advancedExercises.filter { if case .number = $0.answer { true } else { false } }
    #expect(numericTasks.count == expected.count)
    for (suffix, independent) in expected {
        let task = try #require(FoundationLesson.exercise(.init(rawValue: "E.foundation." + suffix)))
        guard case .number(let actual, _) = task.answer else { Issue.record("Numeric key expected: \(suffix)"); continue }
        #expect(abs(actual - independent) < 1e-6, "\(suffix)")
        #expect(task.answer.accepts(.number(independent)), "\(suffix)")
    }
}
