import Foundation
import Testing
@testable import PokerCore

private func cards(_ ids: [Int]) -> [Card] { ids.map(Card.init(id:)) }

// Independent rank/suit aggregation across all seven cards, without selecting
// five-card subsets or using PokerCore's five-card evaluator.
func independentSevenCardRank(_ hand: [Card]) -> [Int] {
    var counts = [Int](repeating: 0, count: 15)
    var suits = [[Int]](repeating: [], count: 4)
    for c in hand { counts[c.rank] += 1; suits[c.suit].append(c.rank) }
    let ranks = (2...14).reversed().filter { counts[$0] > 0 }
    func straight(_ values: [Int]) -> Int? {
        let set = Set(values)
        for high in stride(from: 14, through: 5, by: -1) {
            let needed = high == 5 ? [14, 2, 3, 4, 5] : Array((high-4)...high)
            if needed.allSatisfy(set.contains) { return high }
        }
        return nil
    }
    if let flush = suits.first(where: { $0.count >= 5 }), let high = straight(flush) { return [8, high] }
    if let quad = ranks.first(where: { counts[$0] == 4 }) { return [7,quad,ranks.first { $0 != quad }!] }
    let trips = ranks.filter { counts[$0] >= 3 }
    if let trip = trips.first, let pair = ranks.first(where: { $0 != trip && counts[$0] >= 2 }) { return [6,trip,pair] }
    if let flush = suits.first(where: { $0.count >= 5 }) { return [5] + flush.sorted(by: >).prefix(5) }
    if let high = straight(ranks) { return [4,high] }
    if let trip = trips.first { return [3,trip] + ranks.filter { $0 != trip }.prefix(2) }
    let pairs = ranks.filter { counts[$0] >= 2 }
    if pairs.count >= 2 { return [2,pairs[0],pairs[1],ranks.first { !pairs.prefix(2).contains($0) }!] }
    if let pair = pairs.first { return [1,pair] + ranks.filter { $0 != pair }.prefix(3) }
    return [0] + ranks.prefix(5)
}

@Test func exhaustiveFiveCardCategoryCounts() {
    var counts = [Int](repeating:0,count:9)
    let deck = cards(Array(0..<52))
    for a in 0..<48 { for b in (a+1)..<49 { for c in (b+1)..<50 { for d in (c+1)..<51 { for e in (d+1)..<52 {
        counts[HandEvaluator.best(of:[deck[a],deck[b],deck[c],deck[d],deck[e]]).category] += 1
    } } } } }
    // Each five-card hand appears once. Straight-flush includes royal flush.
    #expect(counts == [1_302_540,1_098_240,123_552,54_912,10_200,5_108,3_744,624,40])
    #expect(counts.reduce(0,+) == 2_598_960)
}

@Test func sevenCardIndependentReference() {
    var rng = SeededGenerator(state: 0xBADC0DE)
    let deck = cards(Array(0..<52))
    for _ in 0..<5000 {
        let hand = Array(deck.shuffled(using:&rng).prefix(7))
        let rank = HandEvaluator.best(of:hand)
        #expect([rank.category] + rank.kickers == independentSevenCardRank(hand))
        #expect(rank.bestFive.count == 5 && Set(rank.bestFive).count == 5)
        #expect(Set(rank.bestFive).isSubset(of:Set(hand)))
    }
}

@Test func completeDealsHaveUniqueCards() throws {
    for seed in 0..<500 {
        var game = HoldemGame(seed:UInt64(seed))
        while !game.snapshot.complete {
            let snapshot=game.snapshot
            let actor=try #require(snapshot.actor)
            let legal=game.legalActions(for:actor)
            try game.act(legal.canCheck ? .check : .call,seat:actor,revision:snapshot.revision)
        }
        let snapshot=game.snapshot
        let dealt=snapshot.players.flatMap(\.cards)+snapshot.board
        #expect(dealt.count == 17 && Set(dealt).count == 17)
        #expect(snapshot.players.reduce(Int64(0)){$0+$1.stack} == 6000)
        #expect(snapshot.actor == nil)
    }
}

@Test func shortOpeningAfterCheckFollowsFullBetProfile() throws {
    var game=HoldemGame(seed:42,startingStacks:[1000,1000,15,1000,1000,1000])
    func act(_ action:PokerAction,_ game:inout HoldemGame) throws {
        let s=game.snapshot
        try game.act(action,seat:try #require(s.actor),revision:s.revision)
    }
    for _ in 0..<5 { try act(.call,&game) }
    try act(.check,&game) // BB option, flop.
    try act(.check,&game) // SB checks.
    try act(.allIn,&game) // BB opens remaining 5, below minimum 10.
    #expect(game.legalActions(for:3).minRaiseTo == 15)
    for _ in 0..<4 { try act(.call,&game) }
    #expect(game.snapshot.actor == 1)
    #expect(game.legalActions(for:1).callAmount == 5)
    #expect(game.legalActions(for:1).minRaiseTo == nil)
    #expect(!game.legalActions(for:1).canAllIn)
    try act(.call,&game)
    #expect(game.snapshot.street == "Тёрн")
}

@Test func replayedActionAndSettlementAreRejected() throws {
    var game=HoldemGame(seed:5)
    let original=game.snapshot
    try game.act(.call,seat:3,revision:original.revision)
    #expect(throws:PokerError.staleRevision) { try game.act(.call,seat:3,revision:original.revision) }
    while !game.snapshot.complete {
        let s=game.snapshot;let a=try #require(s.actor)
        try game.act(game.legalActions(for:a).canCheck ? .check : .call,seat:a,revision:s.revision)
    }
    let stacks=game.snapshot.players.map(\.stack)
    #expect(throws:PokerError.wrongTurn) { try game.act(.allIn,seat:0,revision:game.snapshot.revision) }
    #expect(game.snapshot.players.map(\.stack) == stacks)
}

@Test func potOddsAndStoredHistoryAreConsistent() throws {
    let questions=PotOddsQuestion.examples
    #expect(questions.map(\.finalPot) == [200,360,300])
    #expect(abs(questions[0].correctPercent-25)<1e-12)
    #expect(abs(questions[1].correctPercent-100.0/3)<1e-12)
    #expect(abs(questions[2].correctPercent-100.0/6)<1e-12)
    #expect(questions[0].explanation[3].contains("50 / 200"))
    #expect(PracticeAttempt(question:questions[0],answer:24.5).isCorrect)
    #expect(!PracticeAttempt(question:questions[0],answer:24.49).isCorrect)
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let url=directory.appendingPathComponent("history.json")
    let first=PracticeAttempt(question:questions[0],answer:25)
    let second=PracticeAttempt(question:FlushDrawLesson.standard.questions[0],answer:9)
    try PracticeHistory(fileURL:url).save([first,second])
    #expect(try PracticeHistory(fileURL:url).load() == [first,second])
    let bytes=Data("corrupt".utf8);try bytes.write(to:url)
    #expect(throws:(any Error).self) { try PracticeHistory(fileURL:url).load() }
    #expect(try Data(contentsOf:url) == bytes)
}

@Test func randomLegalActionsMatchIndependentPotLedger() throws {
    var rng=SeededGenerator(state:0x51DE907)
    for seed in 0..<1000 {
        let initial=(0..<6).map { _ in Int64(rng.next()%200+1) }
        let button=seed%6
        var game=HoldemGame(seed:UInt64(seed),startingStacks:initial,button:button)
        var ledger=[Int64](repeating:0,count:6)
        ledger[(button+1)%6]=min(5,initial[(button+1)%6])
        ledger[(button+2)%6]=min(10,initial[(button+2)%6])
        var count=0
        while !game.snapshot.complete {
            let s=game.snapshot;let actor=try #require(s.actor);let legal=game.legalActions(for:actor)
            #expect(s.players.reduce(s.pot){$0+$1.stack} == initial.reduce(0,+))
            let roll=rng.next()%6
            let action:PokerAction;let cost:Int64
            if roll==0 && legal.canFold { action = .fold;cost=0 }
            else if roll==1 && legal.canAllIn { action = .allIn;cost=s.players[actor].stack }
            else if roll==2,let minimum=legal.minRaiseTo { action = .raiseTo(minimum);cost=minimum-s.players[actor].contribution }
            else if roll==3,legal.minRaiseTo != nil { action = .raiseTo(legal.maxRaiseTo);cost=s.players[actor].stack }
            else if legal.canCheck { action = .check;cost=0 }
            else { action = .call;cost=legal.callAmount }
            ledger[actor]+=cost
            try game.act(action,seat:actor,revision:s.revision)
            count+=1;try #require(count<180)
        }
        let end=game.snapshot
        var expected=zip(initial,ledger).map(-)
        let order=ledger.indices.sorted { ledger[$0]>ledger[$1] }
        let refund=max(0,ledger[order[0]]-ledger[order[1]])
        expected[order[0]]+=refund;ledger[order[0]]-=refund
        var previous:Int64=0
        for level in Set(ledger.filter{$0>0}).sorted() {
            let contributors=ledger.indices.filter{ledger[$0]>=level}
            let amount=Int64(contributors.count)*(level-previous);previous=level
            let eligible=contributors.filter{!end.players[$0].folded}
            var winners=eligible
            if eligible.count>1 {
                let scores=eligible.map{independentSevenCardRank(end.players[$0].cards+end.board)}
                let top=try #require(scores.max(by:{$0.lexicographicallyPrecedes($1)}))
                winners=zip(eligible,scores).filter{$0.1==top}.map(\.0)
            }
            winners.sort{($0-button+5)%6 < ($1-button+5)%6}
            try #require(!winners.isEmpty)
            for (index,winner) in winners.enumerated() {
                expected[winner]+=amount/Int64(winners.count)+(index<Int(amount%Int64(winners.count)) ? 1:0)
            }
        }
        #expect(end.players.map(\.stack)==expected)
        #expect(end.players.reduce(Int64(0)){$0+$1.stack}==initial.reduce(0,+))
        #expect(end.players.allSatisfy{$0.stack>=0})
    }
}

@Test func specialSevenCardKickersAndTies() {
    func c(_ rank:Int,_ suit:Int)->Card { Card(id:suit*13+rank-2) }
    let twoTrips=[c(14,0),c(14,1),c(14,2),c(13,0),c(13,1),c(13,2),c(2,3)]
    let threePairs=[c(14,0),c(14,1),c(13,0),c(13,1),c(12,0),c(12,1),c(11,3)]
    let quads=[c(8,0),c(8,1),c(8,2),c(8,3),c(14,0),c(13,1),c(2,2)]
    #expect(HandEvaluator.best(of:twoTrips).kickers == [14,13])
    #expect(HandEvaluator.best(of:threePairs).kickers == [14,13,12])
    #expect(HandEvaluator.best(of:quads).kickers == [8,14])
    let royal=(10...14).map{c($0,0)}
    #expect(HandEvaluator.best(of:royal+[c(2,1),c(3,1)]) == HandEvaluator.best(of:royal+[c(14,1),c(14,2)]))
    let wheel=[c(14,0),c(2,1),c(3,2),c(4,3),c(5,0),c(13,3),c(13,1)]
    #expect(HandEvaluator.best(of:wheel).category == 4)
    #expect(HandEvaluator.best(of:wheel).kickers == [5])
}
