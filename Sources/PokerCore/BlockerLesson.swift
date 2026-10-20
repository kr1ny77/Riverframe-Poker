import Foundation

public enum BlockerError: Error { case invalidClass, invalidCards, invalidRange, invalidAnswer }
public enum ComboKind: String, Sendable { case pair, suited, offsuit }
public enum ComboRole: String, Sendable {
    case count, value, bluff
    public var title: String { switch self { case .count: "Подсчёт";case .value: "Value по модели";case .bluff: "Блеф по модели" } }
}

public struct PhysicalCombo: Identifiable, Sendable, Equatable {
    public let cards: [Card]
    public var id: String { cards.map(\.id).sorted().map(String.init).joined(separator:"-") }
    public var title: String { cards.map { $0.rankLabel+$0.symbol }.joined(separator:" ") }
}

public struct ComboHandClass: Identifiable, Sendable {
    public let high: Int
    public let low: Int
    public let kind: ComboKind
    public var id: String { title }
    public var title: String {
        Card(id:high-2).rankLabel+Card(id:low-2).rankLabel+(kind == .pair ? "" : (kind == .suited ? "s" : "o"))
    }
    public init(high:Int,low:Int,kind:ComboKind) throws {
        guard (2...14).contains(high), (2...14).contains(low),
              kind == .pair ? high == low : high > low else { throw BlockerError.invalidClass }
        self.high=high;self.low=low;self.kind=kind
    }
    public var combinations: [PhysicalCombo] {
        var result:[PhysicalCombo]=[]
        for firstSuit in 0..<4 {
            for secondSuit in 0..<4 {
                let matches = switch kind {
                case .pair: firstSuit < secondSuit
                case .suited: firstSuit == secondSuit
                case .offsuit: firstSuit != secondSuit
                }
                if matches { result.append(PhysicalCombo(cards:[Card(id:firstSuit*13+high-2),Card(id:secondSuit*13+low-2)])) }
            }
        }
        return result
    }
}

public struct BlockerRangeEntry: Identifiable, Sendable {
    public let hand: ComboHandClass
    public let role: ComboRole
    public let weight: Int
    public var id: String { hand.id }
    public init(hand:ComboHandClass,role:ComboRole,weight:Int) throws {
        guard (1...1000).contains(weight) else { throw BlockerError.invalidRange }
        self.hand=hand;self.role=role;self.weight=weight
    }
}

public struct ComboExclusion: Identifiable, Sendable {
    public let combo: PhysicalCombo
    public let blockers: [Card]
    public let stage: String
    public var id: String { combo.id }
    public var explanation: String { "\(combo.title) исключена: \(stage) содержит \(blockers.map { $0.rankLabel+$0.symbol }.joined(separator:", "))." }
}

public struct BlockerRow: Identifiable, Sendable {
    public let entry: BlockerRangeEntry
    public let baseline: [PhysicalCombo]
    public let afterHero: [PhysicalCombo]
    public let boardOnly: [PhysicalCombo]
    public let remaining: [PhysicalCombo]
    public let exclusions: [ComboExclusion]
    public var id: String { entry.id }
    init(entry:BlockerRangeEntry,hero:[Card],board:[Card]) {
        self.entry=entry;baseline=entry.hand.combinations
        afterHero=baseline.filter { Set($0.cards).isDisjoint(with:Set(hero)) }
        boardOnly=baseline.filter { Set($0.cards).isDisjoint(with:Set(board)) }
        remaining=afterHero.filter { Set($0.cards).isDisjoint(with:Set(board)) }
        exclusions=baseline.compactMap { combo in
            let privateCards=combo.cards.filter { hero.contains($0) }
            if !privateCards.isEmpty { return ComboExclusion(combo:combo,blockers:privateCards,stage:"Hero") }
            let publicCards=combo.cards.filter { board.contains($0) }
            return publicCards.isEmpty ? nil : ComboExclusion(combo:combo,blockers:publicCards,stage:"доска")
        }
    }
}

public enum BlockerMetric: Sendable { case remainingCount, bluffPercent }
public struct BlockerQuestion: Identifiable, Sendable {
    public let id: String
    public let hero: [Card]
    public let board: [Card]
    public let range: [BlockerRangeEntry]
    public let metric: BlockerMetric
    public let choices: [Int]
    public var isRangeModel: Bool { range.allSatisfy { $0.role != .count } }
    public var rows: [BlockerRow] { range.map { BlockerRow(entry:$0,hero:hero,board:board) } }
    public var remainingCount: Int { rows.reduce(0) { $0+$1.remaining.count } }
    public var valueMass: Int { rows.filter { $0.entry.role == .value }.reduce(0) { $0+$1.remaining.count*$1.entry.weight } }
    public var bluffMass: Int { rows.filter { $0.entry.role == .bluff }.reduce(0) { $0+$1.remaining.count*$1.entry.weight } }
    public var bluffPercent: Double? { valueMass+bluffMass > 0 ? 100*Double(bluffMass)/Double(valueMass+bluffMass) : nil }
    public var prompt: String {
        metric == .bluffPercent ? "Какая доля массы заданного диапазона после удаления приходится на учебные блефы?" : "Сколько физических комбинаций во всём показанном наборе останется после учёта Hero и доски?"
    }
    public func choiceTitle(_ index:Int) -> String { "\(choices[index]) \(metric == .bluffPercent ? "%" : "комбинаций")" }
    public func accepts(_ index:Int) -> Bool {
        guard choices.indices.contains(index) else { return false }
        if metric == .remainingCount { return choices[index] == remainingCount }
        return valueMass+bluffMass > 0 && 100*bluffMass == choices[index]*(valueMass+bluffMass)
    }
    public var correctIndex: Int? { choices.indices.first { accepts($0) } }
    public var lessonNote: String {
        switch id {
        case "blockers-aa-v1": "Из четырёх тузов доступны A♦ и A♣. C(2,2) = 1: A♦A♣. Каждый неупорядоченный набор считаем один раз."
        case "blockers-aks-v1": "Сочетания одной масти: A♠K♠, A♥K♥, A♦K♦, A♣K♣. Hero убирает пики и бубны, доска — черви. Остаются трефы."
        case "blockers-ako-v1": "После всех известных карт доступны два туза и три короля: 2 × 3 = 6 сочетаний AK. Среди них A♣K♣ одномастная, поэтому AKo = 6 − 1 = 5."
        case "blockers-range-v1": "AA сокращается до одной value-комбинации, KQs — до трёх учебных блефов. При весе 1 на каждую доля блефов равна 3/4. Value-рука A♦A♣ всё ещё возможна."
        case "blockers-weights-v1": "Физических комбинаций по-прежнему четыре. Вес 3 единственной AA даёт ту же массу, что три KQs с весом 1: доля блефов становится 50%. Количество карт и вероятностная масса измеряют разные величины."
        case "blockers-bluffs-v1": "Q♠ и Q♦ убирают две KQs, сохраняя все AA, доступные по доске. Доля блефов уменьшается с 4/7 в каталоге одной доски до 2/5 с учётом Hero. Блокирование блефов тоже меняет нормировку."
        default: Self.scope
        }
    }
    public init(id:String,hero:[Card],board:[Card],range:[BlockerRangeEntry],metric:BlockerMetric,choices:[Int]) throws {
        let cards=hero+board
        guard hero.count == 2, (3...5).contains(board.count), Set(cards).count == cards.count,
              cards.allSatisfy({(0..<52).contains($0.id)}) else { throw BlockerError.invalidCards }
        guard (1...8).contains(range.count), Set(range.map(\.id)).count == range.count,
              (2...4).contains(choices.count), Set(choices).count == choices.count,
              choices.allSatisfy({(0...1326).contains($0)}),
              range.allSatisfy({$0.role == .count}) || range.allSatisfy({$0.role != .count}),
              metric != .bluffPercent || choices.allSatisfy({(0...100).contains($0)}),
              metric != .bluffPercent || range.allSatisfy({$0.role != .count}) else { throw BlockerError.invalidRange }
        self.id=id;self.hero=hero;self.board=board;self.range=range;self.metric=metric;self.choices=choices
    }
    public static let scope = "Блокер делает конкретные руки невозможными. Доля блефов относится к заданному диапазону и весам после ставки; реальные карты соперника остаются неизвестны. Для решения Call/Fold дополнительно нужны цена и equity."
    public static let rangeConditions = "Модель NLHE cash: Hero BTN против BB на ривере, остальные fold. До ставки банк 100 фишек; BB ставит последние 50, у Hero 50. Рейк 0, анте 0, один банк. В заданной модели после ставки у BB только AA (value) и KQs (блеф); вес назначен каждой физической комбинации. Предыдущая линия учтена только этими заданными весами."
    public static let examples: [Self] = {
        let hero=[Card(id:12),Card(id:37)], flop=[Card(id:25),Card(id:44),Card(id:28)]
        let river=flop+[Card(id:0),Card(id:20)]
        let aa=try! ComboHandClass(high:14,low:14,kind:.pair)
        let aks=try! ComboHandClass(high:14,low:13,kind:.suited)
        let ako=try! ComboHandClass(high:14,low:13,kind:.offsuit)
        let kqs=try! ComboHandClass(high:13,low:12,kind:.suited)
        func entry(_ hand:ComboHandClass,_ role:ComboRole = .count,_ weight:Int = 1) -> BlockerRangeEntry { try! .init(hand:hand,role:role,weight:weight) }
        return [
            try! .init(id:"blockers-aa-v1",hero:hero,board:flop,range:[entry(aa)],metric:.remainingCount,choices:[3,1,6]),
            try! .init(id:"blockers-aks-v1",hero:hero,board:flop,range:[entry(aks)],metric:.remainingCount,choices:[4,2,1]),
            try! .init(id:"blockers-ako-v1",hero:hero,board:flop,range:[entry(ako)],metric:.remainingCount,choices:[5,7,12]),
            try! .init(id:"blockers-range-v1",hero:hero,board:river,range:[entry(aa,.value),entry(kqs,.bluff)],metric:.remainingCount,choices:[10,4,7]),
            try! .init(id:"blockers-weights-v1",hero:hero,board:river,range:[entry(aa,.value,3),entry(kqs,.bluff)],metric:.bluffPercent,choices:[50,75,100]),
            try! .init(id:"blockers-bluffs-v1",hero:[Card(id:10),Card(id:36)],board:river,range:[entry(aa,.value),entry(kqs,.bluff)],metric:.bluffPercent,choices:[75,50,40])
        ]
    }()
}

public struct BlockerAttempt: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let questionID: String
    public let answerIndex: Int
    public let isCorrect: Bool
    public var question: BlockerQuestion? { BlockerQuestion.examples.first { $0.id == questionID } }
    public var isValid: Bool { question.map { $0.choices.indices.contains(answerIndex) && isCorrect == $0.accepts(answerIndex) } ?? false }
    public init(questionID:String,answerIndex:Int) throws {
        guard let q=BlockerQuestion.examples.first(where:{$0.id == questionID}), q.choices.indices.contains(answerIndex) else { throw BlockerError.invalidAnswer }
        id=UUID();date=Date();self.questionID=questionID;self.answerIndex=answerIndex;isCorrect=q.accepts(answerIndex)
    }
}
