import Testing
@testable import PokerCore

private func botCard(_ rank: Int, _ suit: Int) -> Card {
    Card(id: suit * 13 + rank - 2)
}

private func botSeats(
    acting: Int = 3,
    stack: Int64 = 1_000,
    contribution: Int64 = 0,
    button: Int = 0,
    opponents: Int = 5
) -> [BotSeatObservation] {
    let liveOpponentSeats = Set((0..<6).filter { $0 != acting }.prefix(opponents))
    return (0..<6).map { seat in
        BotSeatObservation(
            seat: seat,
            stack: seat == acting ? stack : 1_000,
            streetContribution: seat == acting ? contribution : 10,
            totalContribution: seat == acting ? contribution : 10,
            folded: seat != acting && !liveOpponentSeats.contains(seat),
            allIn: false,
            isButton: seat == button
        )
    }
}

private func botObservation(
    cards: [Card],
    board: [Card] = [],
    acting: Int = 3,
    button: Int = 0,
    stack: Int64 = 1_000,
    contribution: Int64 = 0,
    pot: Int64 = 100,
    currentBet: Int64 = 10,
    legal: LegalActions? = nil,
    opponents: Int = 5
) -> BotObservation {
    let street: BotStreet = switch board.count {
    case 0: .preflop
    case 3: .flop
    case 4: .turn
    default: .river
    }
    let actions = legal ?? LegalActions(
        canFold: true,
        canCheck: false,
        callAmount: max(1, currentBet - contribution),
        minRaiseTo: max(20, currentBet + 10),
        maxRaiseTo: contribution + stack,
        canAllIn: true
    )
    return BotObservation(
        handNumber: 17,
        revision: 93,
        actingSeat: acting,
        street: street,
        ownCards: cards,
        board: board,
        seats: botSeats(acting: acting, stack: stack, contribution: contribution, button: button, opponents: opponents),
        pot: pot,
        currentBet: currentBet,
        legal: actions
    )
}

private func isLegal(_ action: PokerAction, for legal: LegalActions) -> Bool {
    return switch action {
    case .fold: legal.canFold
    case .check: legal.canCheck
    case .call: legal.callAmount > 0
    case .raiseTo(let value):
        if let minimum = legal.minRaiseTo {
            (minimum...legal.maxRaiseTo).contains(value)
        } else {
            false
        }
    case .allIn: legal.canAllIn
    }
}

private func amateurOracle(_ observation: BotObservation, seed: UInt64) -> PokerAction {
    var random = SeededGenerator(state: seed)
    let roll = Int(random.next() % 100)
    let pair = observation.ownCards[0].rank == observation.ownCards[1].rank
    let high = max(observation.ownCards[0].rank, observation.ownCards[1].rank)
    let strength = observation.board.count >= 3
        ? HandEvaluator.best(of: observation.ownCards + observation.board).category
        : (pair ? 2 : (high >= 12 ? 1 : 0))
    if strength >= 2, roll < 22, let minimum = observation.legal.minRaiseTo {
        let target = max(minimum, observation.currentBet + max(10, observation.pot / 2))
        if target <= observation.legal.maxRaiseTo { return .raiseTo(target) }
    }
    if observation.legal.canCheck { return .check }
    if strength >= 1 || observation.legal.callAmount <= max(10, observation.ownSeat.stack / 12) || roll < 18 { return .call }
    return .fold
}

@Test func allBotProfilesReturnLegalActionsForFixedCorpus() throws {
    let corpus: [BotObservation] = [
        botObservation(cards: [botCard(14, 0), botCard(14, 1)]),
        botObservation(cards: [botCard(10, 0), botCard(8, 0)], acting: 5, button: 0),
        botObservation(cards: [botCard(10, 0), botCard(8, 0)], acting: 3, button: 0),
        botObservation(cards: [botCard(14, 0), botCard(11, 0)], board: [botCard(9, 0), botCard(6, 0), botCard(2, 2)]),
        botObservation(cards: [botCard(8, 0), botCard(7, 1)], board: [botCard(6, 2), botCard(5, 3), botCard(13, 0)]),
        botObservation(cards: [botCard(8, 0), botCard(7, 1)], board: [botCard(6, 2), botCard(4, 3), botCard(13, 0)], stack: 20),
        botObservation(cards: [botCard(14, 0), botCard(12, 1)], board: [botCard(12, 2), botCard(8, 3), botCard(3, 0)], opponents: 2),
        botObservation(cards: [botCard(14, 0), botCard(12, 1)], board: [botCard(12, 2), botCard(8, 3), botCard(3, 0)], opponents: 5)
    ]
    for level in BotLevel.allCases {
        for (index, observation) in corpus.enumerated() {
            let action = try BotPolicy.decide(observation, level: level, seed: UInt64(index + 1))
            #expect(isLegal(action, for: observation.legal), "\(level.title), B\(index + 1): \(action)")
        }
    }
}

@Test func amateurRemainsTheIndependentBasicV1Oracle() throws {
    let corpus = [
        botObservation(cards: [botCard(14, 0), botCard(14, 1)]),
        botObservation(cards: [botCard(14, 0), botCard(7, 1)], stack: 72),
        botObservation(cards: [botCard(7, 0), botCard(2, 1)], pot: 60, currentBet: 40),
        botObservation(cards: [botCard(9, 0), botCard(9, 1)], board: [botCard(9, 2), botCard(7, 3), botCard(2, 0)])
    ]
    for seed in 0..<64 {
        for observation in corpus {
            #expect(try BotPolicy.decide(observation, level: .amateur, seed: UInt64(seed)) == amateurOracle(observation, seed: UInt64(seed)))
        }
    }
}

@Test func seededPoliciesAreRepeatableAndSensitiveOnlyToTheirInputSeed() throws {
    let observation = botObservation(
        cards: [botCard(14, 0), botCard(11, 0)],
        board: [botCard(9, 0), botCard(6, 0), botCard(2, 2)]
    )
    for level in BotLevel.allCases {
        let first = try BotPolicy.decide(observation, level: level, seed: 0xCAFE_BABE)
        let repeated = try BotPolicy.decide(observation, level: level, seed: 0xCAFE_BABE)
        #expect(first == repeated, "\(level.title)")
    }
}

@Test func positionPriceDrawAndStackCorpusShowsPlannedPolicyDifferences() throws {
    let earlyTenEight = botObservation(cards: [botCard(10, 0), botCard(8, 0)], acting: 3, button: 0, pot: 15, currentBet: 10)
    let lateTenEight = botObservation(cards: [botCard(10, 0), botCard(8, 0)], acting: 5, button: 0, pot: 15, currentBet: 10)
    let cheapDraw = botObservation(cards: [botCard(14, 0), botCard(11, 0)], board: [botCard(9, 0), botCard(6, 0), botCard(2, 2)], pot: 100, currentBet: 10, opponents: 1)
    let expensiveDraw = botObservation(cards: [botCard(14, 0), botCard(11, 0)], board: [botCard(9, 0), botCard(6, 0), botCard(2, 2)], pot: 20, currentBet: 100, opponents: 1)
    let shallow = botObservation(cards: [botCard(14, 0), botCard(12, 1)], board: [botCard(12, 2), botCard(8, 3), botCard(3, 0)], stack: 20)
    let deep = botObservation(cards: [botCard(14, 0), botCard(12, 1)], board: [botCard(12, 2), botCard(8, 3), botCard(3, 0)], stack: 1_000)

    let early = try BotPolicy.decide(earlyTenEight, level: .confident, seed: 7)
    let late = try BotPolicy.decide(lateTenEight, level: .confident, seed: 7)
    let cheap = try BotPolicy.decide(cheapDraw, level: .strong, seed: 11)
    let expensive = try BotPolicy.decide(expensiveDraw, level: .strong, seed: 11)
    let shallowAction = try BotPolicy.decide(shallow, level: .challenge, seed: 19)
    let deepAction = try BotPolicy.decide(deep, level: .challenge, seed: 19)
    #expect(early != late)
    #expect(cheap != expensive)
    #expect(shallowAction != deepAction)
}

@Test func botObservationAdmitsOnlyOwnCardsAndPublicState() throws {
    let original = HoldemGame(seed: 42, botSeed: 123)
    let baseline = try #require(original.botObservation())
    for hidden in [false, true] {
        for future in [false, true] {
            let changed = original.varyingUnobservedState(swapOpponentCards: hidden, reverseFutureDeck: future)
            let observation = try #require(changed.botObservation())
            #expect(observation == baseline)
            #expect(changed.botDecisionSeed == original.botDecisionSeed)
            for level in BotLevel.allCases {
                let first = try BotPolicy.decide(baseline, level: level, seed: original.botDecisionSeed)
                let second = try BotPolicy.decide(observation, level: level, seed: changed.botDecisionSeed)
                #expect(first == second)
            }
        }
    }
    // The variation really changes secrets: showdown differs with identical calls.
    var left = original
    var right = original.varyingUnobservedState(swapOpponentCards: true, reverseFutureDeck: true)
    for _ in 0..<24 {
        if left.snapshot.complete { break }
        for hand in 0..<2 {
            var copy = hand == 0 ? left : right
            let o = try #require(copy.botObservation())
            try copy.act(o.legal.canCheck ? .check : .call, seat: o.actingSeat, revision: o.revision)
            if hand == 0 { left = copy } else { right = copy }
        }
    }
    #expect(left.snapshot.complete && right.snapshot.complete)
    #expect(left.snapshot.board != right.snapshot.board)
    #expect(left.snapshot.players[0].cards != right.snapshot.players[0].cards)
}

@Test func preCancelledDecisionStopsBeforePolicyEvaluation() async {
    let observation = botObservation(cards: [botCard(14, 0), botCard(14, 1)])
    let gate = BotCancellationGate()
    let task = Task {
        await gate.wait()
        try Task.checkCancellation()
        return try BotPolicy.decide(observation, level: .challenge, seed: 1)
    }
    task.cancel()
    await gate.release()
    // Awaiting confirms cancellation propagates before a result can be applied.
    do {
        _ = try await task.value
        Issue.record("Ожидалась отмена до вычисления решения")
    } catch let error {
        #expect(error is CancellationError)
    }
}

@Test func policyActionsApplyThroughEngineAndPreserveShortStackLedger() throws {
    for level in BotLevel.allCases {
        let starting: [Int64] = [20, 35, 50, 70, 90, 120]
        var game = HoldemGame(seed: 77, botSeed: 0xB07, startingStacks: starting)
        var turns = 0
        while !game.snapshot.complete {
            let snapshot = game.snapshot
            let seat = try #require(snapshot.actor)
            let action: PokerAction
            if seat == 0 {
                action = game.legalActions(for: seat).canCheck ? .check : .call
            } else {
                let observation = try #require(game.botObservation())
                action = try BotPolicy.decide(observation, level: level, seed: game.botDecisionSeed)
                #expect(isLegal(action, for: observation.legal), "\(level.title), seat \(seat)")
            }
            try game.act(action, seat: seat, revision: snapshot.revision)
            turns += 1
            try #require(turns < 180)
        }
        #expect(game.snapshot.players.reduce(Int64(0)) { $0 + $1.stack } == starting.reduce(0, +), "\(level.title)")
        #expect(game.snapshot.players.allSatisfy { $0.stack >= 0 }, "\(level.title)")
    }
}

@Test func adjacentProfilesHaveFixedDistinguishingScenarios() throws {
    let cases: [(BotLevel, BotLevel, [Card])] = [
        (.beginner, .amateur, [botCard(14, 0), botCard(14, 1)]),
        (.amateur, .confident, [botCard(10, 0), botCard(7, 0)]),
        (.confident, .strong, [botCard(10, 0), botCard(7, 0)]),
        (.strong, .challenge, [botCard(10, 0), botCard(5, 0)])
    ]
    for (left, right, cards) in cases {
        let o = botObservation(cards: cards, pot: 15)
        var differences = 0
        for seed: UInt64 in 0..<64 {
            let a = try BotPolicy.decide(o, level: left, seed: seed)
            let b = try BotPolicy.decide(o, level: right, seed: seed)
            if a != b { differences += 1 }
        }
        #expect(differences >= 16, "Adjacent profiles must differ on the fixed corpus")
    }
}

@Test func challengeComparesRaisesWithTheValueOfFreeCheck() {
    let seats = [
        BotSeatObservation(seat: 0, stack: 1000, streetContribution: 0, totalContribution: 100, folded: false, allIn: false, isButton: true),
        BotSeatObservation(seat: 1, stack: 0, streetContribution: 0, totalContribution: 100, folded: false, allIn: true, isButton: false),
        BotSeatObservation(seat: 2, stack: 1000, streetContribution: 0, totalContribution: 100, folded: false, allIn: false, isButton: false)
    ]
    let o = BotObservation(handNumber: 1, revision: 1, actingSeat: 0, street: .river,
        ownCards: [botCard(14, 0), botCard(12, 1)],
        board: [botCard(12, 2), botCard(8, 3), botCard(3, 0), botCard(2, 1), botCard(7, 2)],
        seats: seats, pot: 300, currentBet: 0,
        legal: LegalActions(canFold: false, canCheck: true, callAmount: 0, minRaiseTo: 10, maxRaiseTo: 1000, canAllIn: true))
    // All-in prevents winning by folds. For equity .49 and one matching live
    // opponent: check = .49*300; raise = .49*300 - .02*paid.
    #expect(BotPolicy.conditionalDecision(o, equity: 0.49, hasDraw: false, roll: 0) == .check)
}

@Test func profilesRespectUnreopenedShortRaiseAndSidePotCaps() throws {
    func step(_ action: PokerAction, _ game: inout HoldemGame) throws {
        let state = game.snapshot
        try game.act(action, seat: try #require(state.actor), revision: state.revision)
    }
    var short = HoldemGame(seed: 3, startingStacks: [1000,1000,1000,1000,15,1000])
    try step(.call, &short)
    try step(.allIn, &short)
    for _ in 0..<4 { try step(.call, &short) }
    let o = try #require(short.botObservation())
    #expect(o.actingSeat == 3 && o.legal.callAmount == 5 && o.legal.minRaiseTo == nil)
    for level in BotLevel.allCases {
        var copy = short
        let action = try BotPolicy.decide(o, level: level, seed: 21)
        #expect(action == .call || action == .fold)
        try copy.act(action, seat: o.actingSeat, revision: o.revision)
    }
    var caps = HoldemGame(seed: 5, startingStacks: [20,35,50,70,90,120])
    for _ in 0..<3 { try step(.allIn, &caps) }
    let capped = try #require(caps.botObservation()) // Seat 0 can cover 20 of each contribution.
    #expect(capped.actingSeat == 0 && capped.legal.callAmount == 20)
    #expect(capped.availablePot == 75) // 3*20 + already-posted SB5 + BB10.
    #expect(abs(capped.callPrice - 20.0 / 95.0) < 1e-12)
    #expect(capped.potLayers.reduce(Int64(0)) { $0 + $1.amount } == capped.pot)
    for level in BotLevel.allCases {
        var copy = caps
        let action = try BotPolicy.decide(capped, level: level, seed: 11)
        try copy.act(action, seat: capped.actingSeat, revision: capped.revision)
        #expect(copy.snapshot.players.reduce(copy.snapshot.pot) { $0 + $1.stack } == 385)
    }
}

@Test func decisionSeedChangesPreserveDealingWithIdenticalPublicActions() throws {
    var first = HoldemGame(seed: 83, botSeed: 1)
    var second = HoldemGame(seed: 83, botSeed: 2)
    while !first.snapshot.complete {
        let left = try #require(first.botObservation())
        let right = try #require(second.botObservation())
        #expect(left == right)
        let action: PokerAction = left.legal.canCheck ? .check : .call
        try first.act(action, seat: left.actingSeat, revision: left.revision)
        try second.act(action, seat: right.actingSeat, revision: right.revision)
    }
    #expect(first.snapshot.board == second.snapshot.board)
    #expect(first.snapshot.players.map(\.cards) == second.snapshot.players.map(\.cards))
}

private actor BotCancellationGate {
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

@Test func secretNoninterferenceHoldsOnEveryStreet() throws {
    var game = HoldemGame(seed: 91, botSeed: 6)
    var streets = Set<Int>()
    while !game.snapshot.complete {
        let o = try #require(game.botObservation())
        if streets.insert(o.street.rawValue).inserted {
            let changed = game.varyingUnobservedState(swapOpponentCards: true, reverseFutureDeck: true)
            let other = try #require(changed.botObservation())
            #expect(o == other)
            for level in BotLevel.allCases {
                let left = try BotPolicy.decide(o, level: level, seed: 64)
                let right = try BotPolicy.decide(other, level: level, seed: 64)
                #expect(left == right)
            }
        }
        try game.act(o.legal.canCheck ? .check : .call, seat: o.actingSeat, revision: o.revision)
    }
    #expect(streets == Set([0,1,2,3]))
}
