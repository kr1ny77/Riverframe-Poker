import Foundation

public struct Card: Identifiable, Hashable, Codable, Sendable {
    public let id: Int
    public var rank: Int { id % 13 + 2 }
    public var suit: Int { id / 13 }
    public var rankLabel: String {
        switch rank { case 14: "A"; case 13: "K"; case 12: "Q"; case 11: "J"; default: String(rank) }
    }
    public var symbol: String { ["♠", "♥", "♦", "♣"][suit] }
    public var isRed: Bool { suit == 1 || suit == 2 }
    public var label: String {
        let ranks = ["двойка", "тройка", "четвёрка", "пятёрка", "шестёрка", "семёрка", "восьмёрка", "девятка", "десятка", "валет", "дама", "король", "туз"]
        return "\(ranks[rank - 2]) \(["пик", "червей", "бубен", "треф"][suit])"
    }
    public init(id: Int) { precondition((0..<52).contains(id)); self.id = id }
}

/// Stable version-1 PRNG; deck and decisions use independent streams.
struct SeededGenerator: RandomNumberGenerator, Sendable {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public struct HandRank: Comparable, Equatable, Sendable {
    public let category: Int
    public let kickers: [Int]
    public let bestFive: [Card]
    public var title: String {
        ["Старшая карта", "Пара", "Две пары", "Тройка", "Стрит", "Флеш", "Фулл-хаус", "Каре", "Стрит-флеш"][category]
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.category == rhs.category && lhs.kickers == rhs.kickers
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        return lhs.kickers.lexicographicallyPrecedes(rhs.kickers)
    }
}

public enum HandEvaluator {
    public static func best(of cards: [Card]) -> HandRank {
        precondition((5...7).contains(cards.count) && Set(cards).count == cards.count)
        var result: HandRank?
        let n = cards.count
        for a in 0..<(n-4) {
            for b in (a+1)..<(n-3) {
                for c in (b+1)..<(n-2) {
                    for d in (c+1)..<(n-1) {
                        for e in (d+1)..<n {
                            let rank = five([cards[a],cards[b],cards[c],cards[d],cards[e]])
                            if result == nil || result! < rank { result = rank }
                        }
                    }
                }
            }
        }
        return result!
    }
    private static func five(_ cards: [Card]) -> HandRank {
        let descending = cards.map(\.rank).sorted(by: >)
        let counts = Dictionary(grouping: cards, by: \.rank).mapValues(\.count)
        let groups = counts.sorted { $0.value == $1.value ? $0.key > $1.key : $0.value > $1.value }
        let flush = Set(cards.map(\.suit)).count == 1
        let unique = Array(Set(descending)).sorted(by: >)
        var straightHigh = 0
        if unique.count == 5 {
            if unique[0] - unique[4] == 4 { straightHigh = unique[0] }
            if unique == [14,5,4,3,2] { straightHigh = 5 }
        }
        let category: Int
        let kickers: [Int]
        if flush && straightHigh > 0 { category = 8; kickers = [straightHigh] }
        else if groups[0].value == 4 { category = 7; kickers = groups.map(\.key) }
        else if groups[0].value == 3 && groups[1].value == 2 { category = 6; kickers = groups.map(\.key) }
        else if flush { category = 5; kickers = descending }
        else if straightHigh > 0 { category = 4; kickers = [straightHigh] }
        else if groups[0].value == 3 { category = 3; kickers = groups.map(\.key) }
        else if groups[0].value == 2 && groups[1].value == 2 { category = 2; kickers = groups.map(\.key) }
        else if groups[0].value == 2 { category = 1; kickers = groups.map(\.key) }
        else { category = 0; kickers = descending }
        return HandRank(category: category, kickers: kickers, bestFive: cards)
    }
}
