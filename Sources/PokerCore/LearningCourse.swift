import Foundation

public enum CourseStage: String, CaseIterable, Identifiable, Sendable {
    case basics, probability, equity, positions, ranges, ev, advanced
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .basics: "1. Основы";case .probability: "2. Вероятности и цена колла"
        case .equity: "3. Equity";case .positions: "4. Позиции";case .ranges: "5. Диапазоны"
        case .ev: "6. EV";case .advanced: "7. Продвинутые концепции"
        }
    }
}
public enum CourseLessonID: String, CaseIterable, Identifiable, Sendable {
    case combinations, outs, potOdds, knownEquity, positions, rangeEquity, evCall, blockers
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .combinations: "Комбинации и сравнение рук";case .outs: "Ауты флеш-дро";case .potOdds: "Шансы банка"
        case .knownEquity: "Equity против известной руки";case .positions: "Позиции и стартовые руки"
        case .rangeEquity: "Equity против диапазона";case .evCall: "EV колла и фолда";case .blockers: "Комбинаторика и блокеры"
        }
    }
    public var stage: CourseStage {
        switch self {
        case .combinations: .basics;case .outs,.potOdds: .probability;case .knownEquity: .equity
        case .positions: .positions;case .rangeEquity: .ranges;case .evCall: .ev;case .blockers: .advanced
        }
    }
    /// Advisory teaching sequence; lessons remain accessible for independent study.
    public var prerequisites: [Self] {
        switch self {
        case .combinations: [];case .outs: [.combinations];case .potOdds: [.outs];case .knownEquity: [.potOdds]
        case .positions: [.knownEquity];case .rangeEquity: [.knownEquity,.positions]
        case .evCall: [.potOdds,.rangeEquity];case .blockers: [.rangeEquity,.evCall]
        }
    }
    public var accessibilityID: String {
        switch self {
        case .combinations: "training.combinations";case .outs: "training.outs";case .potOdds: "training.pot-odds"
        case .knownEquity: "training.equity";case .positions: "training.positions";case .rangeEquity: "training.range-equity"
        case .evCall: "training.ev-call";case .blockers: "training.blockers"
        }
    }
    public var requiredKeys: Set<String> {
        switch self {
        case .combinations: Self.comparisonKeys
        case .outs: Set(FlushDrawLesson.standard.questions.map(\.id))
        case .potOdds: Set(PotOddsQuestion.examples.map(\.id))
        case .knownEquity: Set(KnownHandEquityQuestion.examples.map(\.id))
        case .positions: Set(PositionLesson.questions.map(\.id))
        case .rangeEquity: Set(RangeEquityQuestion.examples.map(\.id))
        case .evCall: Set(EVCallQuestion.examples.map(\.id))
        case .blockers: Set(BlockerQuestion.examples.map(\.id))
        }
    }
    private static let comparisonKeys=Set(HandComparisonLesson.questions(seed:1).compactMap { comparisonKey($0.id) })
    static func comparisonKey(_ id:String) -> String? {
        let parts=id.split(separator:"-")
        guard parts.count == 5, parts[0] == "hcmp",parts[1] == "v1" else { return nil }
        return String(parts[2])
    }
}

/// Describes the task where an answer was wrong, rather than inferring its cause.
public enum LearningErrorCategory: String, CaseIterable, Identifiable, Sendable {
    case handOrder, bestFive, kicker, wheel, split, nextCard, byRiver, potPrice, showdownEquity, rangeEquity
    case seat, actionOrder, startingHand, priorActions, evComparison, removal, conditionalWeights
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .handOrder: "Сравнение комбинаций";case .bestFive: "Выбор лучших пяти";case .kicker: "Сравнение кикеров"
        case .wheel: "Туз в младшем стрите";case .split: "Распознавание ничьей";case .nextCard: "Вероятность следующей карты"
        case .byRiver: "Вероятность за два открытия";case .potPrice: "Цена колла и итоговый банк"
        case .showdownEquity: "Equity с учётом дележа";case .rangeEquity: "Equity взвешенного диапазона"
        case .seat: "Распознавание позиции";case .actionOrder: "Очередность действий";case .startingHand: "Свойства стартовой руки"
        case .priorActions: "Контекст предыдущих действий";case .evComparison: "Сравнение EV Call/Fold"
        case .removal: "Подсчёт и удаление комбинаций";case .conditionalWeights: "Условные веса value/блефов"
        }
    }
}

public struct CourseObservation: Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let lesson: CourseLessonID
    public let key: String
    public let category: LearningErrorCategory
    public let isCorrect: Bool
}
public struct CourseErrorSummary: Identifiable, Sendable {
    public let category: LearningErrorCategory
    public let answers: Int
    public let errors: Int
    public let distinctTasks: Int
    public var id: LearningErrorCategory { category }
}
public struct CourseLessonProgress: Sendable {
    public let lesson: CourseLessonID
    public let observations: [CourseObservation]
    public var covered: Int { Set(observations.map(\.key)).count }
    public var completed: Bool { Set(observations.map(\.key)) == lesson.requiredKeys }
    public var latestCorrect: Int {
        Dictionary(grouping:observations,by:\.key).values.filter { $0.last?.isCorrect == true }.count
    }
    public var recent: [CourseObservation] { Array(observations.suffix(20)) }
    public var recentErrors: Int { recent.filter { !$0.isCorrect }.count }
    public var recentDistinct: Int { Set(recent.map(\.key)).count }
    /// Product heuristic for these tasks, without a statistical proficiency claim.
    public var repeatRecommended: Bool {
        recent.count >= 10 && recentDistinct >= min(3,lesson.requiredKeys.count)
            && recentErrors >= 3 && 10*recentErrors >= 3*recent.count
    }
    public var sampleText: String { "Выборка: \(observations.count) ответов · \(covered) разных заданий." }
    public var repeatText: String {
        let sample="Последние \(recent.count) ответов: \(recentErrors) ошибок · \(recentDistinct) разных заданий."
        if repeatRecommended { return sample+" Полезно повторить эти задания; рекомендация — учебная эвристика." }
        if recent.count < 10 || recentDistinct < min(3,lesson.requiredKeys.count) { return sample+" Для рекомендации по правилу курса нужно больше ответов и охвата заданий." }
        return sample+" Продолжайте курс; правило повтора выделяет минимум 3 ошибки при доле от 30%."
    }
    public var errors: [CourseErrorSummary] {
        LearningErrorCategory.allCases.compactMap { category in
            let answers=recent.filter { $0.category == category }
            let errors=answers.filter { !$0.isCorrect }.count
            return errors == 0 ? nil : CourseErrorSummary(category:category,answers:answers.count,errors:errors,distinctTasks:Set(answers.map(\.key)).count)
        }
    }
}

public struct LearningCourseSnapshot: Sendable {
    public let observations: [CourseObservation]
    public let ignoredRecords: Int
    public static let interpretation = "Завершение означает ответы на все задания набора. Точность показана отдельно. Повторы фиксированных задач проверяют эти задачи; перенос навыка требует новых примеров. Качество учебного ответа оценивается по условию задачи; выигрыш виртуальных фишек ведётся в игре."
    private static func signature(_ cards:[Card]) -> String {
        var suits:[Int:Int]=[:]
        return cards.map { card in
            if suits[card.suit] == nil { suits[card.suit]=suits.count }
            return "\(card.rank):\(suits[card.suit]!)"
        }.joined(separator:",")
    }
    private static let comparisonCatalog: [String:(HandComparisonMode,Set<String>)] = {
        Dictionary(uniqueKeysWithValues:HandComparisonLesson.questions(seed:1).map { q in
            let signatures=Set([signature(q.first+q.second+q.board),signature(q.second+q.first+q.board)])
            return (CourseLessonID.comparisonKey(q.id)!,(q.mode,signatures))
        })
    }()
    private static let numericCatalog: [String:(CourseLessonID,LearningErrorCategory,Double)] = {
        var result:[String:(CourseLessonID,LearningErrorCategory,Double)]=[:]
        for q in PotOddsQuestion.examples { result[q.id]=(.potOdds,.potPrice,q.correctPercent) }
        for q in FlushDrawLesson.standard.questions { result[q.id]=(.outs,q.horizon == .nextCard ? .nextCard : .byRiver,q.correctPercent) }
        // Exact v1 vectors, checked against the lesson calculators in course tests.
        // Progress reads perform no board enumeration or asynchronous work.
        for (q,expected) in zip(KnownHandEquityQuestion.examples,[100.0*907/990,50]) { result[q.id]=(.knownEquity,.showdownEquity,expected) }
        for (q,expected) in zip(RangeEquityQuestion.examples,[100.0*907/990,87.5,62.5]) { result[q.id]=(.rangeEquity,.rangeEquity,expected) }
        return result
    }()
    public init(archive:PracticeArchive) {
        var values:[CourseObservation]=[]
        var seen=Set<UUID>(), rejected=0
        func add(id:UUID,date:Date,lesson:CourseLessonID,key:String,category:LearningErrorCategory,correct:Bool) {
            guard lesson.requiredKeys.contains(key), seen.insert(id).inserted else { rejected+=1;return }
            values.append(CourseObservation(id:id,date:date,lesson:lesson,key:key,category:category,isCorrect:correct))
        }
        for a in archive.attempts {
            guard let (lesson,category,expected)=Self.numericCatalog[a.questionID], a.answer.isFinite,
                  (0...100).contains(a.answer), a.correctPercent.isFinite, abs(a.correctPercent-expected)<1e-9,
                  a.isCorrect == (abs(a.answer-expected)<=0.5) else { rejected+=1;continue }
            add(id:a.id,date:a.date,lesson:lesson,key:a.questionID,category:category,correct:a.isCorrect)
        }
        for a in archive.comparisons {
            guard a.isValid, let key=CourseLessonID.comparisonKey(a.question.id),
                  let (mode,signatures)=Self.comparisonCatalog[key],mode == a.question.mode,
                  signatures.contains(Self.signature(a.question.first+a.question.second+a.question.board)) else { rejected+=1;continue }
            let category:LearningErrorCategory
            switch key {
            case "wheel":category = .wheel
            case "kicker":category = .kicker
            case "boardsplit":category = .split
            default:category = a.question.mode == .bestFive ? .bestFive : .handOrder
            }
            add(id:a.id,date:a.date,lesson:.combinations,key:key,category:category,correct:a.isCorrect)
        }
        for a in archive.positions {
            guard a.isValid else { rejected+=1;continue }
            let category:LearningErrorCategory
            if a.questionID.contains("recognize-") { category = .seat }
            else if ["preflop","postflop","relative"].contains(where:{a.questionID.hasSuffix($0)}) { category = .actionOrder }
            else { category = a.questionID.hasSuffix("prior-actions") ? .priorActions : .startingHand }
            add(id:a.id,date:a.date,lesson:.positions,key:a.questionID,category:category,correct:a.isCorrect)
        }
        for a in archive.evCalls {
            guard a.isValid else { rejected+=1;continue }
            add(id:a.id,date:a.date,lesson:.evCall,key:a.questionID,category:.evComparison,correct:a.isCorrect)
        }
        for a in archive.blockers {
            guard a.isValid else { rejected+=1;continue }
            let category:LearningErrorCategory = ["blockers-weights-v1","blockers-bluffs-v1"].contains(a.questionID) ? .conditionalWeights : .removal
            add(id:a.id,date:a.date,lesson:.blockers,key:a.questionID,category:category,correct:a.isCorrect)
        }
        // Equal timestamps retain the recorded array order within each lesson.
        observations=values.enumerated().sorted {
            $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date < $1.element.date
        }.map(\.element)
        ignoredRecords=rejected
    }
    public func progress(_ lesson:CourseLessonID) -> CourseLessonProgress { CourseLessonProgress(lesson:lesson,observations:observations.filter { $0.lesson == lesson }) }
    public var completedLessons: Int { CourseLessonID.allCases.filter { progress($0).completed }.count }
    public var repeatLessons: [CourseLessonID] { CourseLessonID.allCases.filter { progress($0).repeatRecommended } }
    public var nextLesson: CourseLessonID? {
        CourseLessonID.allCases.first { lesson in !progress(lesson).completed && lesson.prerequisites.allSatisfy { progress($0).completed } } ?? repeatLessons.first
    }
}
