import Foundation

public enum PokerAction: Equatable, Sendable {
    case fold, check, call, raiseTo(Int64), allIn
}
public struct LegalActions: Sendable {
    public let canFold: Bool
    public let canCheck: Bool
    public let callAmount: Int64
    public let minRaiseTo: Int64?
    public let maxRaiseTo: Int64
    public let canAllIn: Bool
    public static let none = LegalActions(canFold:false,canCheck:false,callAmount:0,minRaiseTo:nil,maxRaiseTo:0,canAllIn:false)
}
public struct PlayerSnapshot: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let position: String
    public let stack: Int64
    public let contribution: Int64
    public let folded: Bool
    public let allIn: Bool
    public let isButton: Bool
    public let cards: [Card]
    public let lastAction: String
}
public struct GameSnapshot: Sendable {
    public let revision: Int
    public let handNumber: Int
    public let street: String
    public let actor: Int?
    public let players: [PlayerSnapshot]
    public let board: [Card]
    /// Committed chips while active; awarded total remains visible after settlement.
    public let pot: Int64
    public let currentBet: Int64
    public let complete: Bool
    public let result: String
    public let log: [String]
    public let legal: LegalActions
}
public enum PokerError: LocalizedError, Equatable {
    case wrongTurn, staleRevision, illegalAction, invalidAmount, handInProgress
    public var errorDescription: String? {
        switch self {
        case .wrongTurn: "Дождитесь своего хода."
        case .staleRevision: "Состояние обновилось. Проверьте действие."
        case .illegalAction: "Это действие сейчас недоступно."
        case .invalidAmount: "Проверьте сумму и минимальный размер повышения."
        case .handInProgress: "Сначала завершите текущую раздачу."
        }
    }
}
struct Seat: Sendable {
    var stack: Int64
    var street: Int64 = 0
    var total: Int64 = 0
    var folded = false
    var cards: [Card] = []
    var lastAction = "Ожидает"
    // Reopening target after the player's last action; nil means yet to act.
    var reopenAt: Int64?
}

public struct HoldemGame: Sendable {
    private var seats: [Seat]
    private var deck: [Card] = []
    private var cursor = 0
    private var board: [Card] = []
    private var streetIndex = 0
    private var actor: Int?
    private var pending = Set<Int>()
    private var currentBet: Int64 = 10
    private var lastFullRaise: Int64 = 10
    private var button: Int
    private var revision = 0
    private var handNumber = 0
    private var complete = true
    private var result = ""
    private var publicLog: [String] = []
    private var awardedPot: Int64 = 0
    private var deckRNG: SeededGenerator
    private var botRNG: SeededGenerator
    private var handBudget: Int64 = 0

    /// Fixed six-seat table. Zero stacks are topped up before each new hand.
    public init(seed: UInt64 = UInt64.random(in: 1...UInt64.max), startingStacks: [Int64] = Array(repeating:1000,count:6), button: Int = 0) {
        precondition(startingStacks.count == 6 && startingStacks.allSatisfy { (1...1_000_000).contains($0) })
        precondition((0..<6).contains(button))
        seats = startingStacks.map { Seat(stack:$0) }
        self.button = button
        deckRNG = SeededGenerator(state:seed)
        botRNG = SeededGenerator(state:seed ^ 0xA5A5A5A5A5A5A5A5)
        beginHand()
    }

    public var snapshot: GameSnapshot {
        let show = complete && board.count == 5 && seats.filter({ !$0.folded }).count > 1
        let players = seats.indices.map { i in
            PlayerSnapshot(id:i,name:name(i),position:position(i),stack:seats[i].stack,
                contribution:seats[i].street,folded:seats[i].folded,
                allIn:!complete && seats[i].stack == 0 && !seats[i].folded,
                isButton:i == button,cards:(i == 0 || (show && !seats[i].folded)) ? seats[i].cards : [],lastAction:seats[i].lastAction)
        }
        return GameSnapshot(revision:revision,handNumber:handNumber,street:["Префлоп","Флоп","Тёрн","Ривер"][streetIndex],actor:actor,players:players,board:board,pot:complete ? awardedPot : seats.reduce(0){$0+$1.total},currentBet:currentBet,complete:complete,result:result,log:publicLog,legal:actor == 0 ? legalActions(for:0) : .none)
    }

    public mutating func nextHand() throws {
        guard complete else { throw PokerError.handInProgress }
        button = (button+1)%6
        beginHand()
    }

    public mutating func act(_ action: PokerAction, seat: Int, revision expectedRevision: Int) throws {
        guard expectedRevision == revision else { throw PokerError.staleRevision }
        guard actor == seat, !complete else { throw PokerError.wrongTurn }
        var next = self
        try next.apply(action, seat:seat)
        next.revision += 1
        assert(next.seats.reduce(0) { $0+$1.stack+$1.total } == next.handBudget)
        self = next
    }

    func legalActions(for i: Int) -> LegalActions {
        guard actor == i, !complete, !seats[i].folded, seats[i].stack > 0 else { return .none }
        let s = seats[i]
        let owed = max(0,currentBet-s.street)
        let canRaise = (s.reopenAt == nil || currentBet >= s.reopenAt!) && seats.indices.contains { $0 != i && !seats[$0].folded && seats[$0].stack > 0 }
        let maxTo = s.street+s.stack
        let minTo = currentBet == 0 ? 10 : currentBet+lastFullRaise
        return LegalActions(canFold:owed>0,canCheck:owed==0,callAmount:min(owed,s.stack),minRaiseTo:canRaise && maxTo >= minTo ? minTo : nil,maxRaiseTo:maxTo,canAllIn:s.stack <= owed || (canRaise && maxTo>currentBet))
    }

    /// A basic heuristic, based solely on the acting seat's cards and public state.
    public func botAction() -> PokerAction {
        guard let i=actor else { return .check }
        let legal = legalActions(for:i)
        let cards = seats[i].cards
        let pair = cards[0].rank == cards[1].rank
        let high = max(cards[0].rank,cards[1].rank)
        let strength = board.count >= 3 ? HandEvaluator.best(of:cards+board).category : (pair ? 2 : (high>=12 ? 1 : 0))
        // Copy the decision stream: requests are pure and only a committed action advances it.
        var random = botRNG
        let roll = Int(random.next()%100)
        if strength >= 2, roll < 22, let minimum=legal.minRaiseTo {
            let target = max(minimum,currentBet+max(10,seats.reduce(0){$0+$1.total}/2))
            if target <= legal.maxRaiseTo { return .raiseTo(target) }
        }
        if legal.canCheck { return .check }
        if strength >= 1 || legal.callAmount <= max(10,seats[i].stack/12) || roll < 18 { return .call }
        return .fold
    }

    private mutating func beginHand() {
        handNumber += 1; revision += 1
        publicLog=[]; result=""; awardedPot=0
        for i in seats.indices {
            let topUp = seats[i].stack == 0
            seats[i] = Seat(stack:topUp ? 1000 : seats[i].stack)
            if topUp { publicLog.append("\(name(i)): учебное пополнение +1 000") }
        }
        handBudget=seats.reduce(0){$0+$1.stack}
        deck=(0..<52).map(Card.init(id:))
        deck.shuffle(using:&deckRNG)
        cursor=0; board=[]; streetIndex=0; complete=false
        currentBet=10; lastFullRaise=10
        for _ in 0..<2 { for offset in 1...6 { let i=(button+offset)%6; seats[i].cards.append(draw()) } }
        let sb=(button+1)%6, bb=(button+2)%6
        pay(min(5,seats[sb].stack),seat:sb); seats[sb].lastAction="Малый блайнд \(seats[sb].street)"
        pay(min(10,seats[bb].stack),seat:bb); seats[bb].lastAction="Большой блайнд \(seats[bb].street)"
        publicLog.append("Раздача \(handNumber) · блайнды 5 / 10")
        pending=Set(seats.indices.filter { seats[$0].stack>0 })
        actor=nextPending(after:bb)
        advance(after:bb)
    }
    private mutating func draw() -> Card { defer { cursor += 1 }; return deck[cursor] }
    private func name(_ i: Int) -> String { i==0 ? "Вы" : "Бот \(i)" }
    private func position(_ i: Int) -> String { ["BTN","SB","BB","UTG","HJ","CO"][(i-button+6)%6] }
    private mutating func pay(_ value: Int64,seat i:Int) {
        seats[i].stack -= value; seats[i].street += value; seats[i].total += value
    }
    private func nextPending(after i:Int) -> Int? {
        for offset in 1...6 { let candidate=(i+offset)%6; if pending.contains(candidate) { return candidate } }
        return nil
    }
    private mutating func apply(_ requested:PokerAction,seat i:Int) throws {
        let legal=legalActions(for:i)
        var action=requested
        if requested == .allIn {
            guard legal.canAllIn else { throw PokerError.illegalAction }
            action = seats[i].stack <= legal.callAmount ? .call : .raiseTo(legal.maxRaiseTo)
        }
        var raised=false
        switch action {
        case .fold:
            guard legal.canFold else { throw PokerError.illegalAction }
            seats[i].folded=true; seats[i].lastAction="Пас"
        case .check:
            guard legal.canCheck else { throw PokerError.illegalAction }
            seats[i].lastAction="Чек"
        case .call:
            guard legal.callAmount>0 else { throw PokerError.illegalAction }
            pay(legal.callAmount,seat:i)
            seats[i].lastAction="Колл \(legal.callAmount)" + (seats[i].stack==0 ? " · олл-ин" : "")
        case .raiseTo(let target):
            let rights = seats[i].reopenAt == nil || currentBet >= seats[i].reopenAt!
            let responder = seats.indices.contains { $0 != i && !seats[$0].folded && seats[$0].stack>0 }
            let minimum=currentBet==0 ? 10 : currentBet+lastFullRaise
            guard rights && responder, target>currentBet, target<=legal.maxRaiseTo,
                  target>=minimum || target==legal.maxRaiseTo else { throw PokerError.invalidAmount }
            let increment=target-currentBet
            pay(target-seats[i].street,seat:i)
            if increment>=lastFullRaise { lastFullRaise=increment }
            seats[i].lastAction = "\(currentBet==0 ? "Ставка" : "Рейз до") \(target)" + (seats[i].stack==0 ? " · олл-ин" : "")
            currentBet=target; raised=true
        case .allIn: throw PokerError.illegalAction
        }
        seats[i].reopenAt=currentBet+lastFullRaise
        pending.remove(i)
        if raised { pending=Set(seats.indices.filter { $0 != i && !seats[$0].folded && seats[$0].stack>0 && seats[$0].street<currentBet }) }
        publicLog.append("\(name(i)): \(seats[i].lastAction)")
        _=botRNG.next()
        advance(after:i)
    }
    private mutating func advance(after i:Int) {
        let live=seats.indices.filter { !seats[$0].folded }
        if live.count==1 { settle();return }
        pending=pending.filter { !seats[$0].folded && seats[$0].stack>0 }
        let withChips=live.filter { seats[$0].stack>0 }
        if withChips.count<=1 {
            // A nominal full big blind is not an extra call against a short all-in
            // once only one player can still act. Only match live actual wagers.
            if let remaining=withChips.first {
                currentBet=live.filter { $0 != remaining }.map { seats[$0].street }.max() ?? 0
            }
            if let remaining=withChips.first, seats[remaining].street<currentBet {
                pending=[remaining];actor=remaining;return
            }
            while board.count<5 { dealNextStreet() }
            settle();return
        }
        if pending.isEmpty {
            if streetIndex==3 { settle();return }
            dealNextStreet()
            for j in seats.indices { seats[j].street=0;seats[j].reopenAt=nil }
            currentBet=0;lastFullRaise=10
            pending=Set(withChips)
            actor=nextPending(after:button)
        } else { actor=nextPending(after:i) }
    }
    private mutating func dealNextStreet() {
        _=draw()
        let count=streetIndex==0 ? 3 : 1
        for _ in 0..<count { board.append(draw()) }
        streetIndex += 1
        publicLog.append(["","Флоп","Тёрн","Ривер"][streetIndex] + ": " + board.map { $0.rankLabel+$0.symbol }.joined(separator:" "))
    }
    private mutating func settle() {
        let live=seats.indices.filter { !seats[$0].folded }
        // Refund the sole unmatched upper contribution, including dead money in coverage.
        let sorted=seats.indices.sorted { seats[$0].total>seats[$1].total }
        if let first=sorted.first, seats[first].total>seats[sorted[1]].total {
            let refund=seats[first].total-seats[sorted[1]].total
            seats[first].total -= refund;seats[first].stack += refund
            seats[first].street=max(0,seats[first].street-refund)
            publicLog.append("\(name(first)): возврат \(refund)")
        }
        let levels=Set(seats.map(\.total).filter{$0>0}).sorted()
        var prior:Int64=0
        var payouts=[Int64](repeating:0,count:6)
        var descriptions:[String]=[]
        for (index,level) in levels.enumerated() {
            let contributors=seats.indices.filter { seats[$0].total>=level }
            let amount=(level-prior)*Int64(contributors.count);prior=level
            let eligible=contributors.filter { !seats[$0].folded }
            precondition(!eligible.isEmpty,"Invalid pot without eligible player")
            var winners:[Int]
            if live.count==1 { winners=live }
            else {
                let ranks=Dictionary(uniqueKeysWithValues:eligible.map { ($0,HandEvaluator.best(of:seats[$0].cards+board)) })
                let best=ranks.values.max()!
                winners=eligible.filter { ranks[$0] == best }
            }
            winners.sort { ($0-button+5)%6 < ($1-button+5)%6 }
            let share=amount/Int64(winners.count), odd=Int(amount%Int64(winners.count))
            for (k,winner) in winners.enumerated() { payouts[winner]+=share+(k<odd ? 1 : 0) }
            let title=index==0 ? "Основной банк" : "Побочный банк \(index)"
            descriptions.append("\(title) \(amount): \(winners.map{name($0)}.joined(separator:", "))")
        }
        awardedPot=seats.reduce(0){$0+$1.total}
        for i in seats.indices {
            seats[i].stack+=payouts[i];seats[i].total=0
            if payouts[i]>0 {
                let title=live.count>1 ? " · \(HandEvaluator.best(of:seats[i].cards+board).title)" : ""
                seats[i].lastAction="Получено \(payouts[i])\(title)"
            }
        }
        result=descriptions.joined(separator:"\n")
        publicLog+=descriptions
        complete=true;actor=nil;pending=[]
    }
}
