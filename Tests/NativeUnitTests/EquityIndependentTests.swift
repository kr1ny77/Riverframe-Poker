import Foundation
import Testing
@testable import PokerCore

private struct EquityFixture: Sendable {
    let name: String
    let hero: [Int]
    let opponent: [Int]
    let board: [Int]
    let expected: [Int] // wins, ties, losses, counted as unordered final boards
    var question: KnownHandEquityQuestion {
        get throws {
            try .init(id:name,hero:hero.map(Card.init(id:)),opponent:opponent.map(Card.init(id:)),board:board.map(Card.init(id:)))
        }
    }
}

private let equityFixtures: [EquityFixture] = [
    .init(name:"lesson-flop",hero:[12,25],opponent:[11,24],board:[0,18,33],expected:[907,0,83]),
    .init(name:"lesson-turn-split",hero:[12,24],opponent:[38,50],board:[8,22,36,39],expected:[0,44,0]),
    .init(name:"royal-flop",hero:[12,11],opponent:[25,24],board:[8,9,10],expected:[990,0,0]),
    .init(name:"zero-flop",hero:[25,24],opponent:[12,11],board:[8,9,10],expected:[0,0,990]),
    .init(name:"royal-turn",hero:[12,11],opponent:[25,24],board:[8,9,10,0],expected:[44,0,0]),
    .init(name:"zero-turn",hero:[25,24],opponent:[12,11],board:[8,9,10,0],expected:[0,0,44]),
    .init(name:"turn-vulnerable-lead",hero:[12,25],opponent:[11,24],board:[0,18,33,40],expected:[42,0,2]),
    .init(name:"turn-two-splits",hero:[11,25],opponent:[23,38],board:[0,1,2,3],expected:[42,2,0])
]

/// Independent traversal: build the deck by rank/suit and visit every ORDERED
/// turn/river pair. Independent evaluator aggregates all seven cards directly.
/// No calls to KnownHandEquityQuestion.calculate or HandEvaluator in this oracle.
private func independentEquity(_ fixture:EquityFixture) throws -> [Int] {
    let known=fixture.hero + fixture.opponent + fixture.board
    var deck:[Int]=[]
    for suit in 0..<4 {
        for rank in 2...14 {
            let id=suit*13+rank-2
            if !known.contains(id) { deck.append(id) }
        }
    }
    #expect(deck.count == (fixture.board.count == 3 ? 45 : 44))
    #expect(Set(deck).isDisjoint(with:Set(known)))
    var counts=[0,0,0]
    var boards:[String:Int]=[:]
    func visit(_ runout:[Int]) {
        #expect(Set(known+runout).count == known.count+runout.count)
        let board=fixture.board+runout
        let first=independentSevenCardRank((fixture.hero+board).map(Card.init(id:)))
        let second=independentSevenCardRank((fixture.opponent+board).map(Card.init(id:)))
        counts[first == second ? 1 : (second.lexicographicallyPrecedes(first) ? 0 : 2)] += 1
        boards[runout.sorted().map(String.init).joined(separator:","),default:0] += 1
    }
    for turn in deck {
        if fixture.board.count == 4 { visit([turn]) }
        else {
            for river in deck where river != turn { visit([turn,river]) }
        }
    }
    let multiplicity=fixture.board.count == 3 ? 2 : 1
    #expect(boards.count == (fixture.board.count == 3 ? 990 : 44))
    #expect(boards.values.allSatisfy { $0 == multiplicity })
    #expect(counts.allSatisfy { $0 % multiplicity == 0 })
    return counts.map { $0 / multiplicity }
}

@Test(arguments:equityFixtures)
private func equityMatchesIndependentOracle(_ fixture:EquityFixture) throws {
    let expected=try independentEquity(fixture)
    #expect(expected == fixture.expected)
    let actual=try fixture.question.calculate()
    #expect([actual.wins,actual.ties,actual.losses] == fixture.expected)
    #expect(actual.total == fixture.expected.reduce(0,+))
    // Integer half-pot units: avoids rounding ties before calculating the share.
    let halfPotUnits=2*expected[0]+expected[1]
    let percent=100*Double(halfPotUnits)/Double(2*actual.total)
    #expect(abs(actual.equityPercent-percent) < 1e-12)
    print("EXACT \(fixture.name): W/T/L=\(expected), total=\(actual.total), equity=\(actual.equityPercent)")
}

@Test func equityRejectsEveryDuplicateLocation() throws {
    let valid=[12,25,11,24,0,18,33,40]
    var rejected=0
    for count in [7,8] {
        let cards=Array(valid.prefix(count))
        for first in 0..<(count-1) {
            for second in (first+1)..<count {
                var invalid=cards;invalid[second]=invalid[first]
                #expect(throws:EquityLessonError.invalidCards) {
                    try KnownHandEquityQuestion(id:"duplicate",hero:Array(invalid[0..<2]).map(Card.init(id:)),opponent:Array(invalid[2..<4]).map(Card.init(id:)),board:Array(invalid[4...]).map(Card.init(id:)))
                }
                rejected += 1
            }
        }
    }
    #expect(rejected == 49)
}
