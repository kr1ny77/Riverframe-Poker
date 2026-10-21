import Foundation

/// Published IDs are append-only. Titles and ordering are independent of identity.
public enum CourseTopicID: String, Codable, CaseIterable, Identifiable, Sendable {
    case t01 = "T01"
    case t02 = "T02"
    case t03 = "T03"
    case t04 = "T04"
    case t05 = "T05"
    case t06 = "T06"
    case t07 = "T07"
    case t08 = "T08"
    case t09 = "T09"
    case t10 = "T10"
    case t11 = "T11"
    case t12 = "T12"
    case t13 = "T13"
    case t14 = "T14"
    case t15 = "T15"
    case t16 = "T16"
    case t17 = "T17"
    case t18 = "T18"
    case t19 = "T19"
    case t20 = "T20"
    case t21 = "T21"
    case t22 = "T22"
    case t23 = "T23"
    case t24 = "T24"
    case t25 = "T25"
    case t26 = "T26"
    case t27 = "T27"
    case t28 = "T28"
    case t29 = "T29"
    case t30 = "T30"
    case t31 = "T31"
    case t32 = "T32"
    case t33 = "T33"
    case t34 = "T34"
    case t35 = "T35"
    case t36 = "T36"
    case t37 = "T37"
    case t38 = "T38"
    case t39 = "T39"
    case t40 = "T40"
    case t41 = "T41"
    case t42 = "T42"
    case t43 = "T43"
    case t44 = "T44"
    case t45 = "T45"
    case t46 = "T46"
    case t47 = "T47"
    case t48 = "T48"
    case t49 = "T49"
    case t50 = "T50"
    case t51 = "T51"
    case t52 = "T52"
    case t53 = "T53"
    case t54 = "T54"
    case t55 = "T55"
    case t56 = "T56"
    case t57 = "T57"
    case t58 = "T58"
    case t59 = "T59"
    case t60 = "T60"
    public var id: String { rawValue }
}

public enum CourseModuleID: String, Codable, CaseIterable, Identifiable, Sendable {
    case m01 = "M01"
    case m02 = "M02"
    case m03 = "M03"
    case m04 = "M04"
    case m05 = "M05"
    case m06 = "M06"
    case m07 = "M07"
    case m08 = "M08"
    case m09 = "M09"
    case m10 = "M10"
    case m11 = "M11"
    case m12 = "M12"
    case m13 = "M13"
    case m14 = "M14"
    case m15 = "M15"
    case m16 = "M16"
    case m17 = "M17"
    case m18 = "M18"
    public var id: String { rawValue }
}

public enum CourseLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case foundations, confident, advanced, professional
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .foundations: "Основы"
        case .confident: "Уверенная игра"
        case .advanced: "Продвинутый уровень"
        case .professional: "Профессиональная теория"
        }
    }
}

public struct CatalogExerciseID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public enum CatalogCalculation: Sendable {
    case exactArithmetic, exactEnumeration, conditionalModel, definitions
    public var title: String {
        switch self {
        case .exactArithmetic: "Точный расчёт"
        case .exactEnumeration: "Точный перебор"
        case .conditionalModel: "Точный расчёт в условной модели"
        case .definitions: "Проверка определений"
        }
    }
}

public struct CatalogModule: Identifiable, Sendable {
    public let id: CourseModuleID
    public let title: String
    public let level: CourseLevel
}

public struct CatalogTopic: Identifiable, Sendable {
    public let id: CourseTopicID
    public let title: String
    public let moduleID: CourseModuleID
    public let prerequisites: [CourseTopicID]
    /// A scoped introduction for available material; full lessons remain in their typed providers.
    public let introduction: String?
}

public struct CatalogExercise: Identifiable, Sendable {
    public let id: CatalogExerciseID
    /// Frozen revision of the task and grading semantics, independent of the catalog release.
    public let contentVersion: Int
    public let title: String
    public let lesson: CourseLessonID
    public let legacyKey: String
    public let topicIDs: [CourseTopicID]
    public let calculation: CatalogCalculation

    /// The vertical slice uses the existing typed calculator and save path.
    public var potOddsQuestion: PotOddsQuestion? {
        guard lesson == .potOdds else { return nil }
        return PotOddsQuestion.examples.first { $0.id == legacyKey }
    }
}

public enum CourseCatalog {
    public static let contentVersion = 2
    public static let modules: [CatalogModule] = [
        .init(id: .m01, title: "Правила и банки", level: .foundations),
        .init(id: .m02, title: "Колода и события", level: .foundations),
        .init(id: .m03, title: "Equity и цена решения", level: .foundations),
        .init(id: .m04, title: "Стартовые руки и позиции", level: .foundations),
        .init(id: .m05, title: "Точность оценок", level: .confident),
        .init(id: .m06, title: "Будущая стоимость и рейк", level: .confident),
        .init(id: .m07, title: "Префлоп-линии", level: .confident),
        .init(id: .m08, title: "Условные диапазоны", level: .confident),
        .init(id: .m09, title: "Основы постфлопа", level: .confident),
        .init(id: .m10, title: "Агрессия и план улиц", level: .advanced),
        .init(id: .m11, title: "Распределения и multiway", level: .advanced),
        .init(id: .m12, title: "Частоты и bluff-catching", level: .advanced),
        .init(id: .m13, title: "Стоимость турнирного стека", level: .advanced),
        .init(id: .m14, title: "Теория и солверы", level: .professional),
        .init(id: .m15, title: "Эксплойт и гипотезы", level: .professional),
        .init(id: .m16, title: "Сателлиты", level: .professional),
        .init(id: .m17, title: "Разбор и повторение", level: .professional),
        .init(id: .m18, title: "Риск и процесс", level: .professional),
    ]

    public static let topics: [CatalogTopic] = [
        .init(id: .t01, title: "Лучшая пятёрка, kicker, ничья и wheel", moduleID: .m01, prerequisites: [], introduction: "Сравните лучшие пять карт, кикеры и равные руки. Доступный набор содержит 12 шаблонов вскрытия."),
        .init(id: .t02, title: "Позиции и порядок действий", moduleID: .m01, prerequisites: [.t01], introduction: "Определите место относительно кнопки и порядок ходов в 6-max. Сфолдившие участники пропускаются при выборе очереди."),
        .init(id: .t03, title: "Блайнды, анте, эффективный стек и SPR", moduleID: .m01, prerequisites: [.t02], introduction: "Посчитайте банк после обязательных взносов, эффективный остаток и SPR на заданной улице. Анте и момент измерения указаны в каждом сценарии."),
        .init(id: .t04, title: "Легальные действия, min-raise и неполный all-in", moduleID: .m01, prerequisites: [.t02, .t03], introduction: "Различите итоговую сумму повышения, последнюю полную прибавку и право на повторное повышение после коротких all-in."),
        .init(id: .t05, title: "Side pots, odd chips и возврат лишней ставки", moduleID: .m01, prerequisites: [.t01, .t04], introduction: "Разложите вклады по слоям банка, проверьте участников каждого слоя, возврат непокрытой суммы и нечётную фишку."),
        .init(id: .t06, title: "Комбинации и события без возвращения", moduleID: .m02, prerequisites: [.t01], introduction: "Физические комбинации и известные карты разобраны в прежнем уроке блокеров. Новые задачи добавляют события без возвращения и условные знаменатели."),
        .init(id: .t07, title: "Точные outs и dirty outs", moduleID: .m02, prerequisites: [.t01, .t06], introduction: "Прежние задачи считают шанс собрать флеш. Новый блок различает чистые и грязные ауты против заданной руки."),
        .init(id: .t08, title: "Точная equity против известной руки", moduleID: .m03, prerequisites: [.t01, .t06], introduction: "Прежний точный перебор дополнен подсчётом доли ничьих и проверкой физически возможного входа."),
        .init(id: .t09, title: "Equity против взвешенного диапазона", moduleID: .m03, prerequisites: [.t06, .t08], introduction: "Проверьте нормировку весов, альтернативные ветви диапазона и пересечения с известными картами."),
        .init(id: .t10, title: "Monte Carlo, дисперсия оценщика и ошибка", moduleID: .m05, prerequisites: [.t08, .t09], introduction: nil),
        .init(id: .t11, title: "Pot odds и EV call/fold", moduleID: .m03, prerequisites: [.t08, .t09], introduction: "Цена колла делится на итоговый банк. EV дополнительно учитывает equity и сравнивается с нулём фолда."),
        .init(id: .t12, title: "Bet EV, fold equity и чистый блеф", moduleID: .m10, prerequisites: [.t11], introduction: nil),
        .init(id: .t13, title: "Raise, reshove и all-in EV", moduleID: .m10, prerequisites: [.t04, .t05, .t11, .t12], introduction: nil),
        .init(id: .t14, title: "Implied odds, reverse implied odds и доминирование", moduleID: .m06, prerequisites: [.t07, .t11], introduction: nil),
        .init(id: .t15, title: "Rake и cap", moduleID: .m06, prerequisites: [.t11], introduction: nil),
        .init(id: .t16, title: "Variance, размер выборки и интервал", moduleID: .m05, prerequisites: [.t10], introduction: nil),
        .init(id: .t17, title: "Байесовское обновление диапазона и предположения о блефе", moduleID: .m08, prerequisites: [.t06, .t09, .t16], introduction: nil),
        .init(id: .t18, title: "Blockers и removal effects", moduleID: .m08, prerequisites: [.t06, .t09], introduction: "Исключите комбинации с известными картами. Доли value и блефов относятся к заданным учебным весам."),
        .init(id: .t19, title: "MDF и bluff:value в toy river game", moduleID: .m12, prerequisites: [.t11, .t12, .t18], introduction: nil),
        .init(id: .t20, title: "Bluff-catcher и порог колла", moduleID: .m12, prerequisites: [.t11, .t18, .t19], introduction: nil),
        .init(id: .t21, title: "Свойства стартовых рук и доминирование", moduleID: .m04, prerequisites: [.t01, .t06], introduction: "Прежние задачи о масти и кикере дополнены доминированием в явно заданном диапазоне и контрпримером универсальной силы руки."),
        .init(id: .t22, title: "Open-raise и чарты по позиции", moduleID: .m04, prerequisites: [.t02, .t21], introduction: "Определите RFI и прочитайте паспорт чарта. Небольшая авторская таблица служит условной моделью для чтения меток."),
        .init(id: .t23, title: "Защита BB", moduleID: .m07, prerequisites: [.t22, .t11], introduction: nil),
        .init(id: .t24, title: "Limp, isolation и dead money", moduleID: .m07, prerequisites: [.t22, .t23], introduction: nil),
        .init(id: .t25, title: "3-bet, 4-bet и 5-bet", moduleID: .m07, prerequisites: [.t22, .t24], introduction: nil),
        .init(id: .t26, title: "Cold call и squeeze", moduleID: .m07, prerequisites: [.t25], introduction: nil),
        .init(id: .t27, title: "Короткий стек: shove и resteal", moduleID: .m07, prerequisites: [.t04, .t05, .t11, .t25], introduction: nil),
        .init(id: .t28, title: "Heads-up, 6-max и full ring", moduleID: .m04, prerequisites: [.t02, .t22], introduction: "Сравните очередь в HU, 6-max и full ring. Игровая практика приложения остаётся 6-max против пяти ботов."),
        .init(id: .t29, title: "Текстуры доски", moduleID: .m09, prerequisites: [.t01, .t06], introduction: nil),
        .init(id: .t30, title: "Range advantage и nut advantage", moduleID: .m11, prerequisites: [.t09, .t18, .t29], introduction: nil),
        .init(id: .t31, title: "Реализация equity и playability", moduleID: .m11, prerequisites: [.t09, .t11, .t39], introduction: nil),
        .init(id: .t32, title: "Linear, polarized, capped и uncapped", moduleID: .m08, prerequisites: [.t17, .t18], introduction: nil),
        .init(id: .t33, title: "Board coverage", moduleID: .m11, prerequisites: [.t30, .t32], introduction: nil),
        .init(id: .t34, title: "C-bet и delayed c-bet", moduleID: .m09, prerequisites: [.t22, .t29, .t39], introduction: nil),
        .init(id: .t35, title: "Probe bet и donk bet", moduleID: .m09, prerequisites: [.t34], introduction: nil),
        .init(id: .t36, title: "Check-raise", moduleID: .m10, prerequisites: [.t12, .t29, .t34], introduction: nil),
        .init(id: .t37, title: "Value, protection и semi-bluff", moduleID: .m09, prerequisites: [.t11, .t29], introduction: nil),
        .init(id: .t38, title: "Сайзинг, overbet, SPR и план улиц", moduleID: .m10, prerequisites: [.t03, .t12, .t13], introduction: nil),
        .init(id: .t39, title: "IP и OOP", moduleID: .m09, prerequisites: [.t02, .t29], introduction: "Доступна задача о порядке действий CO против BTN и BTN против BB. Полный постфлоп-разбор этой темы запланирован."),
        .init(id: .t40, title: "Multiway pots", moduleID: .m11, prerequisites: [.t05, .t09, .t29, .t39], introduction: nil),
        .init(id: .t41, title: "Равновесие, GTO и предел exploitability", moduleID: .m14, prerequisites: [.t19, .t20], introduction: nil),
        .init(id: .t42, title: "Чувствительность solver-отчёта к входам", moduleID: .m14, prerequisites: [.t30, .t38, .t41], introduction: nil),
        .init(id: .t43, title: "Смешанные действия и допустимое упрощение", moduleID: .m14, prerequisites: [.t42, .t11], introduction: nil),
        .init(id: .t44, title: "Эксплойт, nodelock и малые выборки", moduleID: .m15, prerequisites: [.t16, .t17, .t41, .t42], introduction: nil),
        .init(id: .t45, title: "ICM и chip EV", moduleID: .m13, prerequisites: [.t05, .t09, .t11], introduction: nil),
        .init(id: .t46, title: "Risk premium и bubble factor", moduleID: .m13, prerequisites: [.t45], introduction: nil),
        .init(id: .t47, title: "Баббл, поздняя стадия MTT и pay jumps", moduleID: .m13, prerequisites: [.t45, .t46], introduction: nil),
        .init(id: .t48, title: "Satellite ICM", moduleID: .m16, prerequisites: [.t45, .t47], introduction: nil),
        .init(id: .t49, title: "Короткий стек, анте, push/fold и reshove", moduleID: .m13, prerequisites: [.t27, .t45, .t46], introduction: nil),
        .init(id: .t50, title: "Multiway all-in, side pots и ICM", moduleID: .m13, prerequisites: [.t05, .t09, .t45], introduction: nil),
        .init(id: .t51, title: "Воспроизводимость и валидация solver-модели", moduleID: .m14, prerequisites: [.t42, .t43], introduction: nil),
        .init(id: .t52, title: "Разбор раздачи и контрфактические линии", moduleID: .m17, prerequisites: [.t11, .t17, .t42], introduction: nil),
        .init(id: .t53, title: "Таксономия ошибок и заметки", moduleID: .m17, prerequisites: [.t52], introduction: nil),
        .init(id: .t54, title: "Целенаправленная практика, интервалы и ретест", moduleID: .m17, prerequisites: [.t53], introduction: nil),
        .init(id: .t55, title: "Тильт, усталость и внимание", moduleID: .m18, prerequisites: [], introduction: nil),
        .init(id: .t56, title: "Банкролл, риск и дисперсия", moduleID: .m18, prerequisites: [.t15, .t16], introduction: nil),
        .init(id: .t57, title: "Выбор игры и неопределённость поля", moduleID: .m18, prerequisites: [.t15, .t16, .t44], introduction: nil),
        .init(id: .t58, title: "Live tells, надёжность и обновление Байеса", moduleID: .m18, prerequisites: [.t17, .t16], introduction: nil),
        .init(id: .t59, title: "Ответственная игра: лимиты и признаки риска", moduleID: .m18, prerequisites: [], introduction: nil),
        .init(id: .t60, title: "Capstone: полный аудит решения и независимая проверка", moduleID: .m17, prerequisites: [.t48, .t50, .t51, .t52, .t53, .t54, .t55, .t56, .t57, .t58, .t59], introduction: nil),
    ]

    /// Explicit legacy aliases are retained when future tasks or content revisions are added.
    public static let exercises: [CatalogExercise] = legacyExercisesV1
    public static var foundationExercises: [FoundationExercise] { FoundationLesson.exercises }
    public static func foundations(for topic: CourseTopicID) -> [FoundationExercise] {
        foundationExercises.filter { $0.topicID == topic }
    }
    public static func exerciseIDs(for topic: CourseTopicID) -> Set<CatalogExerciseID> {
        Set(exercises(for: topic).map(\.id) + foundations(for: topic).map(\.id))
    }
    public static var allExerciseIDs: Set<CatalogExerciseID> {
        Set(exercises.map(\.id) + foundationExercises.map(\.id))
    }

    private static let legacyExercisesV1: [CatalogExercise] = [
        .init(id: .init(rawValue: "E.hand.highcard"), contentVersion: 1, title: "Старшая карта", lesson: .combinations, legacyKey: "highcard", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.pair"), contentVersion: 1, title: "Пара", lesson: .combinations, legacyKey: "pair", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.twopair"), contentVersion: 1, title: "Две пары", lesson: .combinations, legacyKey: "twopair", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.set"), contentVersion: 1, title: "Тройка", lesson: .combinations, legacyKey: "set", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.wheel"), contentVersion: 1, title: "Младший стрит", lesson: .combinations, legacyKey: "wheel", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.flush"), contentVersion: 1, title: "Флеш", lesson: .combinations, legacyKey: "flush", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.fullhouse"), contentVersion: 1, title: "Фулл-хаус", lesson: .combinations, legacyKey: "fullhouse", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.quads"), contentVersion: 1, title: "Каре", lesson: .combinations, legacyKey: "quads", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.straightflush"), contentVersion: 1, title: "Стрит-флеш", lesson: .combinations, legacyKey: "straightflush", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.boardsplit"), contentVersion: 1, title: "Ничья на доске", lesson: .combinations, legacyKey: "boardsplit", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.kicker"), contentVersion: 1, title: "Кикер", lesson: .combinations, legacyKey: "kicker", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.hand.straight"), contentVersion: 1, title: "Стрит", lesson: .combinations, legacyKey: "straight", topicIDs: [.t01], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.outs.next"), contentVersion: 1, title: "Флеш на следующей карте", lesson: .outs, legacyKey: "flush-outs-next-v1", topicIDs: [.t07], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.outs.river"), contentVersion: 1, title: "Флеш к риверу", lesson: .outs, legacyKey: "flush-outs-river-v1", topicIDs: [.t07], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.pot.100.50"), contentVersion: 1, title: "Банк 100, ставка 50", lesson: .potOdds, legacyKey: "pot-100-bet-50-v1", topicIDs: [.t11], calculation: .exactArithmetic),
        .init(id: .init(rawValue: "E.pot.120.120"), contentVersion: 1, title: "Банк 120, ставка 120", lesson: .potOdds, legacyKey: "pot-120-bet-120-v1", topicIDs: [.t11], calculation: .exactArithmetic),
        .init(id: .init(rawValue: "E.pot.200.50"), contentVersion: 1, title: "Банк 200, ставка 50", lesson: .potOdds, legacyKey: "pot-200-bet-50-v1", topicIDs: [.t11], calculation: .exactArithmetic),
        .init(id: .init(rawValue: "E.equity.flop"), contentVersion: 1, title: "Две известные руки на флопе", lesson: .knownEquity, legacyKey: "equity-known-flop-v1", topicIDs: [.t08], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.equity.turn"), contentVersion: 1, title: "Ничья на тёрне", lesson: .knownEquity, legacyKey: "equity-known-turn-v1", topicIDs: [.t08], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.position.UTG"), contentVersion: 1, title: "Позиция UTG", lesson: .positions, legacyKey: "position-v1-recognize-UTG", topicIDs: [.t02], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.HJ"), contentVersion: 1, title: "Позиция HJ", lesson: .positions, legacyKey: "position-v1-recognize-HJ", topicIDs: [.t02], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.CO"), contentVersion: 1, title: "Позиция CO", lesson: .positions, legacyKey: "position-v1-recognize-CO", topicIDs: [.t02], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.BTN"), contentVersion: 1, title: "Позиция BTN", lesson: .positions, legacyKey: "position-v1-recognize-BTN", topicIDs: [.t02], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.SB"), contentVersion: 1, title: "Позиция SB", lesson: .positions, legacyKey: "position-v1-recognize-SB", topicIDs: [.t02], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.BB"), contentVersion: 1, title: "Позиция BB", lesson: .positions, legacyKey: "position-v1-recognize-BB", topicIDs: [.t02], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.preflop"), contentVersion: 1, title: "Первый ход до флопа", lesson: .positions, legacyKey: "position-v1-preflop", topicIDs: [.t02], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.postflop"), contentVersion: 1, title: "Первый ход после флопа", lesson: .positions, legacyKey: "position-v1-postflop", topicIDs: [.t02], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.suited"), contentVersion: 1, title: "Одномастная рука", lesson: .positions, legacyKey: "position-v1-suited", topicIDs: [.t21], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.kicker"), contentVersion: 1, title: "Свойство кикера", lesson: .positions, legacyKey: "position-v1-kicker", topicIDs: [.t21], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.prior-actions"), contentVersion: 1, title: "Открытие и ответ на повышение", lesson: .positions, legacyKey: "position-v1-prior-actions", topicIDs: [.t21, .t22], calculation: .definitions),
        .init(id: .init(rawValue: "E.position.relative"), contentVersion: 1, title: "Относительная позиция", lesson: .positions, legacyKey: "position-v1-relative", topicIDs: [.t02, .t39], calculation: .definitions),
        .init(id: .init(rawValue: "E.range.flop"), contentVersion: 1, title: "Диапазон на флопе", lesson: .rangeEquity, legacyKey: "equity-range-flop-v1", topicIDs: [.t09], calculation: .conditionalModel),
        .init(id: .init(rawValue: "E.range.turn-1to3"), contentVersion: 1, title: "Веса 1 к 3", lesson: .rangeEquity, legacyKey: "equity-range-turn-1to3-v1", topicIDs: [.t09], calculation: .conditionalModel),
        .init(id: .init(rawValue: "E.range.turn-3to1"), contentVersion: 1, title: "Веса 3 к 1", lesson: .rangeEquity, legacyKey: "equity-range-turn-3to1-v1", topicIDs: [.t09], calculation: .conditionalModel),
        .init(id: .init(rawValue: "E.ev.positive"), contentVersion: 1, title: "Положительный EV колла", lesson: .evCall, legacyKey: "ev-call-positive-v1", topicIDs: [.t11], calculation: .conditionalModel),
        .init(id: .init(rawValue: "E.ev.negative"), contentVersion: 1, title: "Отрицательный EV колла", lesson: .evCall, legacyKey: "ev-call-negative-v1", topicIDs: [.t11], calculation: .conditionalModel),
        .init(id: .init(rawValue: "E.ev.zero"), contentVersion: 1, title: "Нулевой EV колла", lesson: .evCall, legacyKey: "ev-call-zero-v1", topicIDs: [.t11], calculation: .conditionalModel),
        .init(id: .init(rawValue: "E.blocker.aa"), contentVersion: 1, title: "Комбинации AA", lesson: .blockers, legacyKey: "blockers-aa-v1", topicIDs: [.t06, .t18], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.blocker.aks"), contentVersion: 1, title: "Комбинации AKs", lesson: .blockers, legacyKey: "blockers-aks-v1", topicIDs: [.t06, .t18], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.blocker.ako"), contentVersion: 1, title: "Комбинации AKo", lesson: .blockers, legacyKey: "blockers-ako-v1", topicIDs: [.t06, .t18], calculation: .exactEnumeration),
        .init(id: .init(rawValue: "E.blocker.range"), contentVersion: 1, title: "Комбинации диапазона", lesson: .blockers, legacyKey: "blockers-range-v1", topicIDs: [.t18], calculation: .conditionalModel),
        .init(id: .init(rawValue: "E.blocker.weights"), contentVersion: 1, title: "Веса диапазона", lesson: .blockers, legacyKey: "blockers-weights-v1", topicIDs: [.t18], calculation: .conditionalModel),
        .init(id: .init(rawValue: "E.blocker.bluffs"), contentVersion: 1, title: "Удаление блефов", lesson: .blockers, legacyKey: "blockers-bluffs-v1", topicIDs: [.t18], calculation: .conditionalModel),
    ]

    public static func exercises(for topic: CourseTopicID) -> [CatalogExercise] {
        exercises.filter { $0.topicIDs.contains(topic) }
    }

    public static func exercise(lesson: CourseLessonID, legacyKey: String) -> CatalogExercise? {
        legacyExercisesV1.first { $0.lesson == lesson && $0.legacyKey == legacyKey }
    }
}

public struct CatalogObservation: Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let exerciseID: CatalogExerciseID
    public let contentVersion: Int
    public let isCorrect: Bool
}

public struct CatalogTopicProgress: Sendable {
    public let exerciseIDs: Set<CatalogExerciseID>
    public let observations: [CatalogObservation]
    public var covered: Int { Set(observations.map(\.exerciseID)).count }
    /// Completion describes only the linked, published exercises for this catalog version.
    public var completedAvailableExercises: Bool {
        !exerciseIDs.isEmpty && Set(observations.map(\.exerciseID)) == exerciseIDs
    }
    public var latestCorrect: Int {
        Dictionary(grouping: observations, by: \.exerciseID).values.filter { $0.last?.isCorrect == true }.count
    }
}

/// Pure projection: preserved legacy payloads and typed schema6 answers share stable catalog IDs.
/// Shared exercises map to several topics while retaining one UUID and one stored answer.
public struct CourseCatalogSnapshot: Sendable {
    public let observations: [CatalogObservation]
    public let ignoredRecords: Int

    public init(course: LearningCourseSnapshot, foundations: [FoundationAttempt] = []) {
        var mapped: [CatalogObservation] = []
        var rejected = course.ignoredRecords
        for observation in course.observations {
            guard let exercise = CourseCatalog.exercise(lesson: observation.lesson, legacyKey: observation.key) else {
                rejected += 1
                continue
            }
            mapped.append(CatalogObservation(id: observation.id, date: observation.date,
                exerciseID: exercise.id, contentVersion: exercise.contentVersion, isCorrect: observation.isCorrect))
        }
        for attempt in foundations {
            guard let exercise = FoundationLesson.exercise(attempt.exerciseID),
                  exercise.contentVersion == attempt.contentVersion else { rejected += 1; continue }
            mapped.append(CatalogObservation(id: attempt.id, date: attempt.date, exerciseID: attempt.exerciseID,
                                            contentVersion: attempt.contentVersion, isCorrect: attempt.isCorrect))
        }
        observations = mapped.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
        ignoredRecords = rejected
    }

    public func progress(for topic: CourseTopicID) -> CatalogTopicProgress {
        let ids = CourseCatalog.exerciseIDs(for: topic)
        return CatalogTopicProgress(exerciseIDs: ids, observations: observations.filter { ids.contains($0.exerciseID) })
    }
}
