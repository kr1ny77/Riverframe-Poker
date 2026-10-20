@testable import PokerCore

final class PokerCoreTests: CoreCheckCase {
    private func card(_ rank: Int, _ suit: Int = 0) -> Card { Card(id: suit * 13 + rank - 2) }
    private func act(_ action: PokerAction, in game: inout HoldemGame) throws {
        let state = game.snapshot
        try game.act(action, seat: unwrap(state.actor), revision: state.revision)
    }
    private func passivelyFinish(_ game: inout HoldemGame) throws {
        var turns = 0
        while !game.snapshot.complete {
            let actor = try unwrap(game.snapshot.actor)
            let legal = game.legalActions(for: actor)
            try act(legal.canCheck ? .check : .call, in: &game)
            turns += 1
            assertLessThan(turns, 100)
            if turns >= 100 { break }
        }
    }

    func testAllHandCategoriesAndBestFiveFromSeven() {
        let fixtures: [([Card], Int)] = [
            ([card(14),card(11,1),card(9,2),card(6,3),card(3)],0),
            ([card(14),card(14,1),card(9,2),card(6,3),card(3)],1),
            ([card(14),card(14,1),card(9,2),card(9,3),card(3)],2),
            ([card(14),card(14,1),card(14,2),card(6,3),card(3)],3),
            ([card(9),card(8,1),card(7,2),card(6,3),card(5)],4),
            ([card(14),card(11),card(9),card(6),card(3)],5),
            ([card(14),card(14,1),card(14,2),card(6,3),card(6)],6),
            ([card(14),card(14,1),card(14,2),card(14,3),card(3)],7),
            ([card(14),card(13),card(12),card(11),card(10)],8)
        ]
        for (cards, category) in fixtures {
            assertEqual(HandEvaluator.best(of: cards).category, category)
        }
        let royal = fixtures.last!.0 + [card(2,1),card(2,2)]
        assertEqual(HandEvaluator.best(of: royal).category, 8)
        assertEqual(Set(HandEvaluator.best(of: royal).bestFive), Set(fixtures.last!.0))
    }

    func testWheelLosesToSixHighStraightAndPairKickersBreakTie() {
        let wheel = HandEvaluator.best(of: [card(14),card(2,1),card(3,2),card(4,3),card(5)])
        let sixHigh = HandEvaluator.best(of: [card(6),card(2,1),card(3,2),card(4,3),card(5)])
        assertEqual(wheel.kickers, [5])
        assertLessThan(wheel, sixHigh)
        let aceKicker = HandEvaluator.best(of: [card(10),card(10,1),card(14,2),card(8,3),card(4)])
        let kingKicker = HandEvaluator.best(of: [card(10),card(10,1),card(13,2),card(8,3),card(4)])
        assertGreaterThan(aceKicker, kingKicker)
    }

    func testBoardOnlyRoyalFlushTiesDifferentHoleCards() {
        let board = [card(14),card(13),card(12),card(11),card(10)]
        assertEqual(HandEvaluator.best(of: board + [card(2,1),card(3,2)]),
                       HandEvaluator.best(of: board + [card(9,1),card(9,2)]))
    }

    func testFullSixPlayerHandTraversesAllStreetsAndBigBlindHasOption() throws {
        var game = HoldemGame(seed: 42)
        assertEqual(game.snapshot.actor, 3)
        assertEqual(game.snapshot.pot, 15)
        for seat in [3,4,5,0,1] {
            assertEqual(game.snapshot.actor, seat)
            try act(.call, in: &game)
        }
        assertEqual(game.snapshot.actor, 2)
        assertEqual(game.snapshot.street, "Префлоп")
        assertTrue(game.legalActions(for: 2).canCheck)
        assertEqual(game.legalActions(for: 2).minRaiseTo, 20)
        try act(.check, in: &game)
        for (street, count) in [("Флоп",3),("Тёрн",4),("Ривер",5)] {
            assertEqual(game.snapshot.street, street)
            assertEqual(game.snapshot.board.count, count)
            for seat in [1,2,3,4,5,0] {
                assertEqual(game.snapshot.actor, seat)
                try act(.check, in: &game)
            }
        }
        assertTrue(game.snapshot.complete)
        assertNil(game.snapshot.actor)
        assertEqual(game.snapshot.pot, 60)
        assertEqual(game.snapshot.players.reduce(0) { $0+$1.stack }, 6000)
        assertEqual(Set(game.snapshot.board + game.snapshot.players.flatMap(\.cards)).count, 17)
        assertFalse(game.snapshot.result.isEmpty)
        try game.nextHand()
        assertEqual(game.snapshot.handNumber, 2)
        assertTrue(game.snapshot.players[1].isButton)
    }

    func testFoldsAwardBlindsWithoutRevealingOpponents() throws {
        var game = HoldemGame(seed: 1)
        for _ in 0..<5 { try act(.fold, in: &game) }
        assertTrue(game.snapshot.complete)
        assertTrue(game.snapshot.board.isEmpty)
        assertEqual(game.snapshot.players[2].stack, 1005)
        assertEqual(game.snapshot.players[1].stack, 995)
        assertTrue(game.snapshot.players.dropFirst().allSatisfy { $0.cards.isEmpty })
    }

    func testRejectedActionsPreserveStateAndRevision() throws {
        var game = HoldemGame(seed: 2)
        let original = game.snapshot
        assertThrowsError(try game.act(.call, seat: 0, revision: original.revision)) { assertEqual($0 as? PokerError, .wrongTurn) }
        assertThrowsError(try game.act(.call, seat: 3, revision: original.revision - 1)) { assertEqual($0 as? PokerError, .staleRevision) }
        assertThrowsError(try game.act(.check, seat: 3, revision: original.revision))
        assertThrowsError(try game.act(.raiseTo(19), seat: 3, revision: original.revision))
        assertThrowsError(try game.nextHand())
        assertEqual(game.snapshot.revision, original.revision)
        assertEqual(game.snapshot.pot, original.pot)
        assertEqual(game.snapshot.actor, original.actor)
        assertEqual(game.snapshot.players.map(\.stack), original.players.map(\.stack))
    }

    func testSingleShortAllInDoesNotReopenPreviousCaller() throws {
        var game = HoldemGame(seed: 3, startingStacks: [1000,1000,1000,1000,15,1000])
        try act(.call, in: &game) // Seat 3 acted at 10.
        try act(.allIn, in: &game) // Seat 4 raises to 15.
        for _ in 0..<4 { try act(.call, in: &game) }
        assertEqual(game.snapshot.actor, 3)
        let legal = game.legalActions(for: 3)
        assertEqual(legal.callAmount, 5)
        assertNil(legal.minRaiseTo)
        assertFalse(legal.canAllIn)
        assertThrowsError(try game.act(.raiseTo(25), seat: 3, revision: game.snapshot.revision))
        try act(.call, in: &game)
        assertEqual(game.snapshot.street, "Флоп")
    }

    func testCumulativeShortAllInsReopenPreviousCaller() throws {
        var game = HoldemGame(seed: 4, startingStacks: [1000,1000,1000,1000,15,20])
        try act(.call, in: &game)
        try act(.allIn, in: &game)
        try act(.allIn, in: &game)
        for _ in 0..<3 { try act(.call, in: &game) }
        assertEqual(game.snapshot.actor, 3)
        assertEqual(game.legalActions(for: 3).minRaiseTo, 30)
        try act(.raiseTo(30), in: &game)
        try passivelyFinish(&game)
        assertEqual(game.snapshot.players.reduce(0) { $0+$1.stack }, 4035)
    }

    func testUnequalAllInsCreateSidePotsAndConserveChips() throws {
        var game = HoldemGame(seed: 5, startingStacks: [20,35,50,70,90,120])
        while !game.snapshot.complete { try act(.allIn, in: &game) }
        assertEqual(game.snapshot.board.count, 5)
        assertEqual(game.snapshot.players.reduce(0) { $0+$1.stack }, 385)
        assertTrue(game.snapshot.result.contains("Побочный банк"))
        assertTrue(game.snapshot.log.contains { $0.contains("возврат 30") })
        assertEqual(game.snapshot.pot, 355)
        let state = game.snapshot
        // Independently enumerate each bank's membership and fixed chip amount.
        let banks: [(Int64,[Int])] = [(120,[0,1,2,3,4,5]),(75,[1,2,3,4,5]),(60,[2,3,4,5]),(60,[3,4,5]),(40,[4,5])]
        var expected: [Int64] = [0,0,0,0,0,30] // Uncalled upper 30 are returned.
        for (amount, members) in banks {
            let ranks = members.map { HandEvaluator.best(of: state.players[$0].cards + state.board) }
            let top = try unwrap(ranks.max())
            let winners = zip(members,ranks).filter { $0.1 == top }.map { $0.0 }.sorted { ($0+5)%6 < ($1+5)%6 }
            for (index,winner) in winners.enumerated() {
                expected[winner] += amount/Int64(winners.count) + (index < Int(amount%Int64(winners.count)) ? 1 : 0)
            }
        }
        assertEqual(state.players.map(\.stack), expected)
    }

    func testShortBlindAllInRunsOutAndRefundsUnmatchedSmallBlind() throws {
        for smallBlind: Int64 in [1,1000] {
            let stacks: [Int64] = [1000,smallBlind,2,1000,1000,1000]
            var game = HoldemGame(seed: 8, startingStacks: stacks)
            for seat in [3,4,5,0] {
                assertEqual(game.snapshot.actor, seat)
                try act(.fold, in: &game)
            }
            assertTrue(game.snapshot.complete)
            assertEqual(game.snapshot.board.count, 5)
            assertEqual(game.snapshot.pot, smallBlind == 1 ? 2 : 4)
            assertEqual(game.snapshot.players.reduce(0) { $0+$1.stack }, stacks.reduce(0,+))
            assertTrue(game.snapshot.log.contains { $0.contains(smallBlind == 1 ? "возврат 1" : "возврат 3") })
        }
    }

    func testSplitPotAwardsOddChipClockwiseAfterButton() throws {
        // Seed 7 produces a two-way tie for seats 2 and 3. The folded SB's
        // five dead chips make the pot odd; seat 2 is first after the button.
        var game = HoldemGame(seed: 7)
        for _ in 0..<4 { try act(.call, in: &game) }
        try act(.fold, in: &game)
        try passivelyFinish(&game)
        let state = game.snapshot
        let second = HandEvaluator.best(of: state.players[2].cards + state.board)
        let third = HandEvaluator.best(of: state.players[3].cards + state.board)
        assertEqual(second, third)
        assertEqual(state.pot, 55)
        assertEqual(state.players.map(\.stack), [990,995,1018,1017,990,990])
    }

    func testTwoHundredSeededMixedHandsTerminateConserveAndHideCards() throws {
        for seed in 1...200 {
            let stacks: [Int64] = [1000,15,30,50,200,700]
            var game = HoldemGame(seed: UInt64(seed), startingStacks: stacks)
            var turns = 0
            while !game.snapshot.complete {
                let snapshot = game.snapshot
                assertTrue(snapshot.players.dropFirst().allSatisfy { $0.cards.isEmpty })
                assertEqual(snapshot.players.reduce(snapshot.pot) { $0+$1.stack }, stacks.reduce(0,+))
                let actor = try unwrap(snapshot.actor)
                let legal = game.legalActions(for: actor)
                let action: PokerAction
                if seed % 3 == 0 { action = game.botAction() }
                else if turns % 5 == 0 && legal.canAllIn { action = .allIn }
                else if turns % 7 == 0 && legal.canFold { action = .fold }
                else { action = legal.canCheck ? .check : .call }
                try act(action, in: &game)
                turns += 1
                assertLessThan(turns, 160, "seed \(seed)")
                if turns >= 160 { break }
            }
            assertTrue(game.snapshot.complete, "seed \(seed)")
            assertEqual(game.snapshot.players.reduce(0) { $0+$1.stack }, stacks.reduce(0,+), "seed \(seed)")
            assertTrue(game.snapshot.players.allSatisfy { $0.stack >= 0 })
        }
    }

    func testIdenticalSeedAndActionsReproduceDealAndBots() throws {
        var first = HoldemGame(seed: 99)
        var second = HoldemGame(seed: 99)
        while !first.snapshot.complete {
            assertEqual(first.botAction(), first.botAction())
            assertEqual(first.botAction(), second.botAction())
            let action = first.botAction()
            try act(action, in: &first)
            try act(action, in: &second)
        }
        assertEqual(first.snapshot.board, second.snapshot.board)
        assertEqual(first.snapshot.players.map(\.cards), second.snapshot.players.map(\.cards))
        assertEqual(first.snapshot.players.map(\.stack), second.snapshot.players.map(\.stack))
    }
}
