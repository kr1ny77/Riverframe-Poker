import Foundation

// Dependency-free checks for the Command Line Tools distribution, which lacks
// XCTest and Swift Testing. Every failing expectation increments the exit status.
@MainActor private var failures = 0
@MainActor private var assertions = 0
@MainActor private func expect(_ condition: Bool, _ message: String, file: StaticString, line: UInt) {
    assertions += 1
    if !condition { failures += 1; print("FAIL \(file):\(line): \(message)") }
}
@MainActor func assertEqual<T: Equatable>(_ actual: @autoclosure () throws -> T, _ expected: @autoclosure () throws -> T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    do { let a = try actual(); let e = try expected(); expect(a == e, "\(a) != \(e) \(message)", file:file,line:line) }
    catch { expect(false, "Unexpected error: \(error)",file:file,line:line) }
}
@MainActor func assertEqual(_ actual: Double, _ expected: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    expect(abs(actual-expected) <= accuracy,"\(actual) != \(expected) ± \(accuracy)",file:file,line:line)
}
@MainActor func assertTrue(_ condition: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) { expect(condition,"Expected true \(message)",file:file,line:line) }
@MainActor func assertFalse(_ condition: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) { expect(!condition,"Expected false \(message)",file:file,line:line) }
@MainActor func assertNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { expect(value == nil,"Expected nil",file:file,line:line) }
@MainActor func assertLessThan<T: Comparable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) { expect(actual < expected,"Expected \(actual) < \(expected) \(message)",file:file,line:line) }
@MainActor func assertGreaterThan<T: Comparable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) { expect(actual > expected,"Expected \(actual) > \(expected)",file:file,line:line) }
@MainActor func assertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line, _ handler: (Error) -> Void = { _ in }) {
    do { _ = try expression(); expect(false,"Expected thrown error",file:file,line:line) }
    catch { expect(true,"",file:file,line:line); handler(error) }
}
struct MissingValue: Error {}
@MainActor func unwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value else { expect(false,"Required value missing",file:file,line:line); throw MissingValue() }
    return value
}
@MainActor class CoreCheckCase {
    private var cleanups: [() throws -> Void] = []
    func addTeardownBlock(_ block: @escaping () throws -> Void) { cleanups.append(block) }
    func tearDown() { for cleanup in cleanups { try? cleanup() } }
}

@main
@MainActor struct CheckRunner {
    static func main() {
        let core = PokerCoreTests()
        let practice = PracticeTests()
        let outs = OutsLessonTests()
        let checks: [(String, () throws -> Void)] = [
            ("all evaluator categories and seven-card selection", core.testAllHandCategoriesAndBestFiveFromSeven),
            ("wheel and pair kicker ordering", core.testWheelLosesToSixHighStraightAndPairKickersBreakTie),
            ("board-only tie", core.testBoardOnlyRoyalFlushTiesDifferentHoleCards),
            ("full six-player hand and big blind option", core.testFullSixPlayerHandTraversesAllStreetsAndBigBlindHasOption),
            ("early fold settlement and hidden cards", core.testFoldsAwardBlindsWithoutRevealingOpponents),
            ("rejected commands preserve state", core.testRejectedActionsPreserveStateAndRevision),
            ("short all-in keeps raise closed", core.testSingleShortAllInDoesNotReopenPreviousCaller),
            ("cumulative short all-ins reopen raise", core.testCumulativeShortAllInsReopenPreviousCaller),
            ("unequal all-ins and side pots", core.testUnequalAllInsCreateSidePotsAndConserveChips),
            ("short blind all-in runout and refunds", core.testShortBlindAllInRunsOutAndRefundsUnmatchedSmallBlind),
            ("split pot and odd chip order", core.testSplitPotAwardsOddChipClockwiseAfterButton),
            ("200 deterministic mixed hands", core.testTwoHundredSeededMixedHandsTerminateConserveAndHideCards),
            ("deterministic deal and bot decisions", core.testIdenticalSeedAndActionsReproduceDealAndBots),
            ("pot odds denominator and explanation", practice.testPotOddsUsesFinalPotIncludingCall),
            ("answer tolerance boundaries", practice.testAnswerToleranceIncludesBoundaryAndRejectsOutside),
            ("atomic local persistence round trip", practice.testHistoryMissingFileAndAtomicRoundTripReplacement),
            ("duplicate attempt rejection", practice.testHistoryRejectsDuplicateIDs),
            ("schema and corruption rejection", practice.testHistoryRejectsUnsupportedSchemaAndMalformedJSON),
            ("persisted answer consistency", practice.testHistoryRejectsOutOfRangeAnswerAndInconsistentCorrectness),
            ("outs known cards and nine valid outs", outs.testKnownCardsAndOuts),
            ("outs exact enumeration and analytic formula", outs.testExactCountsMatchHypergeometricFormula),
            ("outs independent evaluator over all 1081 runouts", outs.testIndependentEvaluatorAllRunouts),
            ("outs choice keys and versioned grading", outs.testChoicesAndVersionedGrading),
            ("legacy pot odds and outs results coexist", outs.testLegacyHistoryAndNewLessonCoexist)
        ]
        var passed = 0
        for (name, check) in checks {
            let before = failures
            do { try check() } catch { failures += 1; print("FAIL \(name): \(error)") }
            if before == failures { passed += 1; print("PASS \(name)") }
        }
        core.tearDown()
        practice.tearDown()
        print("Checks: \(passed)/\(checks.count) passed; \(assertions) assertions; \(failures) failures.")
        if failures > 0 { exit(1) }
    }
}
