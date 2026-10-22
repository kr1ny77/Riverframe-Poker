import Foundation

/// Checked arithmetic for the disclosed M10 and M12 teaching trees.  Each
/// strategy input belongs to its exercise passport; this type grades only math.
public enum CourseAggressionMathError: Error, Equatable, Sendable {
    case invalidProbability
    case invalidAmount
    case nonFiniteResult
}

public enum CourseAggressionMath {
    private static func probability(_ value: Double) throws {
        guard value.isFinite, (0 ... 1).contains(value) else {
            throw CourseAggressionMathError.invalidProbability
        }
    }

    private static func amount(_ value: Double, allowsZero: Bool = true) throws {
        guard value.isFinite, allowsZero ? value >= 0 : value > 0 else {
            throw CourseAggressionMathError.invalidAmount
        }
    }

    /// Fold rate for a zero-showdown-equity wager in a one-opponent river tree.
    public static func foldThresholdPercent(pot: Double, bet: Double) throws -> Double {
        try amount(pot)
        try amount(bet, allowsZero: false)
        let denominator = pot + bet
        guard denominator.isFinite, denominator > 0 else { throw CourseAggressionMathError.nonFiniteResult }
        let value = bet / denominator * 100
        guard value.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        return value
    }

    /// EV where a fold wins `pot`; a call reaches `pot + 2 × bet` and has equity.
    public static func betEV(foldRate: Double, equityWhenCalled: Double, pot: Double, bet: Double) throws -> Double {
        try probability(foldRate)
        try probability(equityWhenCalled)
        try amount(pot)
        try amount(bet)
        let finalPot = pot + 2 * bet
        guard finalPot.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        let value = foldRate * pot + (1 - foldRate) * (equityWhenCalled * finalPot - bet)
        guard value.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        return value
    }

    /// Shove tree: a fold wins `pot`; a call reaches the stated final contested pot.
    public static func shoveEV(foldRate: Double, equityWhenCalled: Double, pot: Double, risk: Double, finalContestedPot: Double) throws -> Double {
        try probability(foldRate)
        try probability(equityWhenCalled)
        try amount(pot)
        try amount(risk)
        try amount(finalContestedPot, allowsZero: false)
        guard risk <= finalContestedPot else { throw CourseAggressionMathError.invalidAmount }
        let value = foldRate * pot + (1 - foldRate) * (equityWhenCalled * finalContestedPot - risk)
        guard value.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        return value
    }

    public static func ratio(numerator: Double, denominator: Double) throws -> Double {
        try amount(numerator)
        try amount(denominator, allowsZero: false)
        let value = numerator / denominator
        guard value.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        return value
    }

    /// Heads-up river toy game: alpha is the bluff:value ratio B/V.
    public static func bluffValueRatio(pot: Double, bet: Double) throws -> Double {
        try amount(pot)
        try amount(bet, allowsZero: false)
        let denominator = pot + bet
        guard denominator.isFinite, denominator > 0 else { throw CourseAggressionMathError.nonFiniteResult }
        return try ratio(numerator: bet, denominator: denominator)
    }

    /// Bluff fraction among bets B/(B+V), derived from B/V = bet/(pot+bet).
    public static func bluffFractionPercent(pot: Double, bet: Double) throws -> Double {
        let ratio = try bluffValueRatio(pot: pot, bet: bet)
        let value = ratio / (1 + ratio) * 100
        guard value.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        return value
    }

    public static func mdfPercent(pot: Double, bet: Double) throws -> Double {
        try amount(pot)
        try amount(bet, allowsZero: false)
        let denominator = pot + bet
        guard denominator.isFinite, denominator > 0 else { throw CourseAggressionMathError.nonFiniteResult }
        let value = pot / denominator * 100
        guard value.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        return value
    }

    /// Call EV for a hand that beats the named bluff mass and loses to value mass.
    public static func bluffCatcherEV(bluffShare: Double, potBeforeBet: Double, call: Double) throws -> Double {
        try probability(bluffShare)
        try amount(potBeforeBet)
        try amount(call, allowsZero: false)
        let win = potBeforeBet + call
        guard win.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        let value = bluffShare * win - (1 - bluffShare) * call
        guard value.isFinite else { throw CourseAggressionMathError.nonFiniteResult }
        return value
    }
}

public extension FoundationLesson {
    /// M10 and M12 use finite, disclosed trees.  Numeric outputs are exact for
    /// those trees; every frequency and range is an explicit conditional input.
    static let aggressionExercises: [FoundationExercise] = [
        // MARK: T12 — fold equity and bet EV
        .init(id: "E.foundation.t12.fold-threshold", topicID: .t12, title: "Порог фолдов чистого блефа", purpose: .concept,
              context: ["NLHE cash 6-max, heads-up river: BB Hero действует первым против BTN Villain. Effective stack 100 BB у каждого; доска Q♦ 7♣ 4♥ 2♠ 9♦, Hero J♣T♣; банк до ставки P = 100 BB, ставка b = 50 BB.", "В условной policy Villain: A♣K♦ получает fold, Q♥Q♠ получает call с переменными весами. J♣T♣ имеет нулевую showdown equity против обеих рук. Рейк, ничьи и будущие ставки равны 0.", "F — нормированная масса fold из этих переменных весов; это вход условной модели."],
              question: "Введите break-even F в процентах с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.foldThresholdPercent(pot: 100, bet: 50), tolerance: 0.01),
              explanation: ["После fold Hero получает P = 100 BB; после call теряет b = 50 BB.", "Нулевой EV: F × 100 − (1 − F) × 50 = 0.", "F = 50 / (100 + 50) = 33,33 %."],
              typicalError: "Делить ставку на банк 100 и получать 50 %, пропуская риск ставки в знаменателе.", term: "Fold equity", definition: "Вероятность, что все требуемые соперники сфолдят в заданной ветви дерева.", example: "В heads-up модели F = 40 % означает четыре fold из десяти одинаково взвешенных эпизодов.", method: "Нарисуйте ветви fold и call; для чистого блефа при нулевой equity решите F × P − (1 − F) × b = 0.", assumptions: "Точный расчёт условного HU river-дерева: P=100 BB, b=50 BB, одна реакция, рейк/ничьи/future EV=0. Реальная fold-частота требует диапазон и политику соперника.", resultKind: .conditionalModel,
              diagram: [.init("Fold, F", "+100 BB"), .init("Call, 1 − F", "−50 BB"), .init("Знаменатель F*", "100 + 50 = 150 BB")], cards: [Card(id: 48), Card(id: 47), Card(id: 36), Card(id: 44), Card(id: 15), Card(id: 0), Card(id: 33)], researchAnchor: "nlhe-complete-knowledge-map.md#t12"),
        .init(id: "E.foundation.t12.semi-bluff-tree", topicID: .t12, title: "Ставка с долей выигрышей при колле", purpose: .transfer,
              context: ["NLHE cash 6-max, heads-up river: BB Hero действует первым против BTN Villain; effective stack 100 BB у каждого. Доска Q♦ 7♣ 4♥ 2♠ 9♦, Hero A♠Q♣; P = 100 BB, b = 50 BB, рейк/ничьи/будущие ставки = 0.", "В заданном call-range Villain: Q♥Q♠ вес4 и J♣T♣ вес1; обе руки всегда call. Hero выигрывает только J♣T♣, поэтому e(call)=1/(4+1)=20 %.", "Отдельный авторский вход F=40 %. Ставка и веса не являются рекомендацией для другого диапазона."],
              question: "Введите EV ставки в BB с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.betEV(foldRate: 0.4, equityWhenCalled: 0.2, pot: 100, bet: 50), tolerance: 0.01),
              explanation: ["Fold-ветвь: 0,40 × 100 = 40 BB.", "Call-ветвь: 0,60 × (0,20 × 200 − 50) = −6 BB.", "Итог: 40 − 6 = 34 BB."],
              typicalError: "Применить формулу чистого блефа и потерять equity против call-ветви.", term: "Equity после call", definition: "Доля итогового банка, которую рука получает против явно заданного диапазона продолжения.", example: "e=20 % применяется к P+2b=200 BB только в ветви call.", method: "Сначала вычислите payoff каждой ветви: F×P и (1−F)×(e×(P+2b)−b), затем сложите.", assumptions: "Точный расчёт заданного river-дерева с F=40 % и e=20 %; all-in, один соперник, без рейка. Изменение calling range меняет e.", resultKind: .conditionalModel,
              diagram: [.init("Fold", "40 % × 100 = +40"), .init("Call", "60 % × (20 % × 200 − 50) = −6"), .init("EV", "+34 BB")], cards: [Card(id: 12), Card(id: 49), Card(id: 36), Card(id: 44), Card(id: 15), Card(id: 0), Card(id: 33)], researchAnchor: "nlhe-complete-knowledge-map.md#t12"),
        .init(id: "E.foundation.t12.multiway-boundary", topicID: .t12, title: "Граница fold equity в multiway", purpose: .boundary,
              context: ["NLHE cash 6-max, river multiway: Hero ставит в двух соперников. P=100 BB, b=50 BB, рейк=0.", "Ни диапазоны, ни условные реакции BTN после call CO, ни совместная вероятность двух fold не заданы."],
              question: "Какой вход нужен для корректной fold-ветви?", answer: .choice(options: ["Совместная вероятность, что все требуемые соперники сфолдят", "Только вероятность fold CO", "Только размер ставки Hero"], correct: 0),
              explanation: ["Hero выигрывает банк сразу лишь после fold всех нужных соперников.", "Вероятность fold CO не определяет реакцию BTN.", "Перемножение двух fold-rate допустимо только при явно заданной независимости."],
              typicalError: "Подставить одиночный fold-rate в multiway дерево без условий реакций второго игрока.", term: "Совместная fold-вероятность", definition: "Вероятность события, где все нужные реакции в ветви являются fold.", example: "P(fold CO и fold BTN) — один вход модели, а не два автоматически независимых числа.", method: "Перечислите порядок решений и задайте joint probability либо условные вероятности каждой реакции.", assumptions: "Понятийная граница. Стратегия требует полные ranges, порядок действий, response policy, стек и рейк.", resultKind: .definitions,
              diagram: [.init("CO fold", "переход к BTN"), .init("BTN fold", "Hero получает P"), .init("Любой call", "другая ветвь EV")], researchAnchor: "nlhe-complete-knowledge-map.md#t12"),

        // MARK: T13 — raise and reshove
        .init(id: "E.foundation.t13.shove-tree", topicID: .t13, title: "EV shove с заданной fold-ветвью", purpose: .concept,
              context: ["NLHE cash heads-up, river. Банк P=120 BB; у Hero осталось 60 BB, BTN покрывает 60 BB.", "Авторская модель BTN: fold F=30 %; при call equity Hero e=45 %. Рейк/ничьи/будущие улицы=0.", "После call contested pot=120+60+60=240 BB. Это chip EV cash-дерева."],
              question: "Введите EV shove в BB с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.shoveEV(foldRate: 0.3, equityWhenCalled: 0.45, pot: 120, risk: 60, finalContestedPot: 240), tolerance: 0.01),
              explanation: ["Fold-ветвь: 0,30 × 120 = 36 BB.", "Call-ветвь: 0,70 × (0,45 × 240 − 60) = 33,6 BB.", "EV shove = 69,6 BB."],
              typicalError: "Добавить 60 BB BTN в банк ещё раз после его fold.", term: "Shove EV", definition: "Сумма payoff всех заданных ветвей all-in решения.", example: "При call конечный contested pot 240 BB включает оба новых вклада по 60 BB.", method: "Отделите P, риск Hero, F, equity против call-range и final contested pot; затем сложите ветви.", assumptions: "Точная арифметика указанного cash HU дерева. F и e относятся к заданной policy BTN; реальные ranges, рейк и ICM меняют вывод.", resultKind: .conditionalModel,
              diagram: [.init("Fold 30 %", "+120 BB"), .init("Call 70 %", "45 % × 240 − 60"), .init("EV", "69,60 BB")], researchAnchor: "nlhe-complete-knowledge-map.md#t13"),
        .init(id: "E.foundation.t13.short-cover", topicID: .t13, title: "Покрытие короткого стека", purpose: .transfer,
              context: ["NLHE cash heads-up, river. P=120 BB; Hero объявляет shove 60 BB, BTN покрывает только 40 BB.", "В модели при call Hero имеет e=45 %, F=0, рейк/ничьи=0. Непокрытые 20 BB Hero возвращаются.", "Оспариваемый банк после call: 120+40+40=200 BB; новый риск Hero=40 BB."],
              question: "Введите EV call-ветви Hero в BB с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.shoveEV(foldRate: 0, equityWhenCalled: 0.45, pot: 120, risk: 40, finalContestedPot: 200), tolerance: 0.01),
              explanation: ["Вклад выше покрытия BTN не становится contested money.", "Call payoff: 0,45 × 200 − 40 = 50 BB.", "Возвращённые 20 BB не являются ни риском, ни частью оспариваемого банка."],
              typicalError: "Использовать риск 60 BB и final pot 240 BB, хотя BTN может contest лишь 40 BB.", term: "Эффективный стек", definition: "Меньший доступный для оспаривания стек среди участников банка.", example: "Hero60 против BTN40 создаёт contested вклад по 40 BB.", method: "До EV ограничьте новые вклады меньшим покрываемым стеком и верните избыток владельцу.", assumptions: "Точная арифметика short-stack cash ветви. Side pots отсутствуют, потому что участвуют два игрока; диапазон и equity заданы.", resultKind: .conditionalModel,
              diagram: [.init("Вклад Hero", "40 BB contested + 20 BB return"), .init("Вклад BTN", "40 BB"), .init("Call EV", "45 % × 200 − 40 = 50")], researchAnchor: "nlhe-complete-knowledge-map.md#t13"),
        .init(id: "E.foundation.t13.raise-facing-bet", topicID: .t13, title: "All-in raise после river bet", purpose: .transfer,
              context: ["NLHE cash 6-max, heads-up river: BTN Villain bet, BB Hero отвечает; effective stack 100 BB у каждого. До ставки банк P=100 BB; Villain bet40 BB, поэтому перед решением Hero pot=140 BB.", "Hero ещё не вкладывал фишки на river и делает raise-to100 BB all-in; Villain уже внёс40 BB и добавляет60 BB до 100. Оба effective stack покрывают total100.", "Авторская модель: Villain fold F=30 %, при call equity Hero e=40 %. Рейк, ничьи и future action=0; final contested pot при call=100+100+100=300 BB."],
              question: "Введите EV raise Hero в BB с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.shoveEV(foldRate: 0.3, equityWhenCalled: 0.4, pot: 140, risk: 100, finalContestedPot: 300), tolerance: 0.01),
              explanation: ["После fold Hero выигрывает pot140 BB, включая уже внесённые 40 BB Villain.", "После call: 0,40×300−100=20 BB; эта ветвь имеет вес 70 %.", "EV=0,30×140+0,70×20=56 BB."],
              typicalError: "Считать raise-to100 как добавку Hero60 BB: Hero на river ещё не вложил фишек, а 60 BB добавляет Villain.", term: "Raise-to", definition: "Полный размер ставки игрока после его действия, включая его собственный вклад на текущей улице.", example: "Facing bet40 Hero raise-to100 вносит100, а bettor добавляет60.", method: "Зафиксируйте pot после исходной ставки, отдельно подпишите вклад raiser и недостающую добавку bettor, затем вычислите обе EV-ветви.", assumptions: "Точная арифметика указанного HU cash river-дерева: P100 до bet, bet40, raise-to100, F30 %, e40 %, рейк0. Частоты и calling range остаются условными входами.", resultKind: .conditionalModel,
              diagram: [.init("До raise", "P=100+bet40=140 BB"), .init("Villain fold 30 %", "+140 BB"), .init("Villain call 70 %", "40 % × 300 − 100 = +20 BB")], researchAnchor: "nlhe-complete-knowledge-map.md#t13"),
        .init(id: "E.foundation.t13.icm-boundary", topicID: .t13, title: "Граница chip EV all-in", purpose: .boundary,
              context: ["MTT учебный сценарий: Hero и BTN играют all-in; chip EV дерева положителен.", "Показаны только стеки Hero и BTN. Выплаты, стеки остальных игроков, число мест и конечные состояния не заданы."],
              question: "Что нужно для денежной оценки ICM этого решения?", answer: .choice(options: ["Полная выплата, все стеки и terminal states после fold/call", "Только chip EV shove", "Только две карты Hero"], correct: 0),
              explanation: ["ICM оценивает доли выплат из распределения всех стеков.", "Одно chip EV число измеряется фишками и не задаёт денежную ценность стека.", "Terminal states нужны для веса каждой ветви решения."],
              typicalError: "Перенести положительный cash chip EV в денежный EV турнира.", term: "Chip EV и денежная ценность", definition: "Chip EV измеряется фишками; ICM переводит заданные конечные стеки в доли заявленной выплаты.", example: "Одинаковый выигрыш 60 BB может иметь разную денежную цену при разных payout и стеках поля.", method: "Сначала составьте все конечные стеки каждой ветви, затем примените модель выплат отдельно от chip EV.", assumptions: "Понятийная граница MTT. Игровой стол приложения сохраняет cash-practice 6-max; ICM присутствует только в учебных сценариях.", resultKind: .definitions,
              diagram: [.init("Fold state", "все стеки после fold"), .init("Call-win state", "все стеки после выигрыша"), .init("Call-loss state", "все стеки после проигрыша")], researchAnchor: "nlhe-complete-knowledge-map.md#t13"),

        // MARK: T36 — check-raise
        .init(id: "E.foundation.t36.call-price", topicID: .t36, title: "Цена колла против check-raise", purpose: .concept,
              context: ["NLHE cash 6-max, flop heads-up BTN/BB. BB checks первым; BTN bet4 BB в начальный банк12 BB; BB check-raise до16 BB total.", "У BB осталось16 BB после check и BTN покрывает этот стек; после call торговля завершена и runout вскрывается. BTN уже вложил4 BB и добавляет12 BB; итоговый банк44 BB; рейк=0."],
              question: "Введите требуемую долю банка для колла BTN в процентах с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.ratio(numerator: 12, denominator: 44) * 100, tolerance: 0.01),
              explanation: ["BTN добавляет 16−4=12 BB.", "Итоговый банк: 12+16+16=44 BB.", "12/44=27,27 %."],
              typicalError: "Считать BTN полные 16 BB вместо добавки после уже внесённой ставки 4 BB.", term: "Check-raise", definition: "Игрок сначала checks, затем raises ставку соперника на той же улице.", example: "BB check, BTN bet4, BB raise-to16 — check-raise.", method: "Покажите вклад каждого игрока до и после raise; цену caller считайте как недостающую добавку.", assumptions: "Точная цена all-in на этой улице; cash 6-max, HU flop, effective stacks покрывают action, рейк/future EV=0. Range choice остаётся моделью.", resultKind: .exact,
              diagram: [.init("BTN уже внёс", "4 BB"), .init("BTN добавляет", "12 BB"), .init("Знаменатель", "44 BB")], researchAnchor: "nlhe-complete-knowledge-map.md#t36"),
        .init(id: "E.foundation.t36.raise-fold-threshold", topicID: .t36, title: "Порог fold для чистого check-raise", purpose: .transfer,
              context: ["NLHE cash 6-max, HU flop. P=12 BB, BTN bet4 BB, BB check-raise до 16 BB total.", "BB имеет нулевую equity после call. Для чистого дерева BB рискует 16 BB ради immediately available pot 12+4=16 BB.", "Fold BTN=F — заданный вход; рейк и будущие улицы=0."],
              question: "Введите break-even F для BB в процентах с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.foldThresholdPercent(pot: 16, bet: 16), tolerance: 0.01),
              explanation: ["После fold BB получает 16 BB, доступные до его raise.", "После call в этом чистом блеф-дереве теряет 16 BB.", "F*=16/(16+16)=50,00 %."],
              typicalError: "Использовать final pot 44 BB в fold-ветви, хотя BTN не добавил 12 BB при fold.", term: "Immediate pot", definition: "Банк, уже доступный агрессору до ответа на его raise.", example: "После bet4 в P12 immediate pot для BB равен 16 BB.", method: "Для чистого блефа отделите pot, который уже существует, от денег, появляющихся только после call.", assumptions: "Точное локальное дерево с zero showdown equity. Реальная частота fold зависит от board, ranges, stacks, позиции и response policy BTN.", resultKind: .conditionalModel,
              diagram: [.init("BTN fold", "+16 BB"), .init("BTN call", "−16 BB в чистой модели"), .init("F*", "16 / 32 = 50 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t36"),
        .init(id: "E.foundation.t36.range-boundary", topicID: .t36, title: "Граница ярлыка check-raise", purpose: .boundary,
              context: ["NLHE cash 6-max, BB check-raise flop на доске 6♠5♦4♣ против BTN c-bet.", "Карты BB, диапазоны, стек, размер ставки и последующие действия не заданы."],
              question: "Какой вывод о диапазоне BB корректен?", answer: .choice(options: ["Check-raise доказывает set", "Нужны board, ranges, stacks, size и policy ответов", "Check-raise всегда чистый bluff"], correct: 1),
              explanation: ["Одно действие не определяет точную руку.", "В условном диапазоне могут быть value, draw и bluff с разными весами.", "Размер и эффективный стек меняют дерево продолжений."],
              typicalError: "Назвать весь диапазон сильным или блефовым по одному названию действия.", term: "Паспорт линии", definition: "Набор позиции, board, pot, size, effective stack, ranges, рейка и response policy для конкретного дерева.", example: "Set может быть в defend range BB, если его комбинации совместимы с известными картами.", method: "Сначала составьте список совместимых комбинаций и их веса, затем оценивайте ветви fold/call/raise.", assumptions: "Понятийная задача; стратегические веса остаются условной моделью без проверенной таблицы полного паспорта.", resultKind: .definitions,
              diagram: [.init("Value", "веса заданы"), .init("Draw", "веса заданы"), .init("Bluff", "веса заданы")], researchAnchor: "nlhe-complete-knowledge-map.md#t36"),

        // MARK: T38 — sizing and street plan
        .init(id: "E.foundation.t38.flop-spr", topicID: .t38, title: "SPR в начале flop", purpose: .concept,
              context: ["NLHE cash 6-max, heads-up flop. Банк P=20 BB; effective stack S=80 BB; рейк=0.", "SPR определяется до ставки текущей улицы."],
              question: "Введите SPR с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.ratio(numerator: 80, denominator: 20), tolerance: 0.01),
              explanation: ["SPR=S/P.", "80/20=4,00.", "Это отношение стеков к банку, единиц у него нет."],
              typicalError: "Подставить стек после будущей ставки, хотя вопрос фиксирует начало flop.", term: "SPR", definition: "Отношение эффективного остатка стека к банку в заданный момент улицы.", example: "S80 и P20 дают SPR4.", method: "Зафиксируйте момент расчёта, затем делите effective stack на текущий pot.", assumptions: "Точная арифметика cash HU. SPR не выбирает сайзинг без board, ranges, позиции и response model.", resultKind: .exact,
              diagram: [.init("Effective stack", "80 BB"), .init("Pot", "20 BB"), .init("SPR", "80 / 20 = 4")], researchAnchor: "nlhe-complete-knowledge-map.md#t38"),
        .init(id: "E.foundation.t38.turn-overbet", topicID: .t38, title: "Turn SPR и overbet", purpose: .transfer,
              context: ["Тот же cash HU flop: P20, S80. Hero bet15, Villain call15; рейк=0.", "На turn банк P=50 BB, эффективные остатки S=65 BB. Hero ставит 65 BB.", "Board, ranges и response policy не заданы: вычисляется только размер и достижимость."],
              question: "Введите размер turn ставки в процентах текущего банка с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.ratio(numerator: 65, denominator: 50) * 100, tolerance: 0.01),
              explanation: ["После bet15/call15: P=20+15+15=50 BB.", "Остатки: 80−15=65 BB; turn SPR=65/50=1,30.", "65/50×100=130 %, значит ставка превышает pot."],
              typicalError: "Сравнить 65 с исходным flop pot 20 вместо текущего turn pot 50.", term: "Overbet", definition: "Ставка, превышающая текущий pot в момент решения.", example: "65 BB в P50 равны 130 % pot.", method: "После каждой ставки обновляйте pot и effective stack, затем сравнивайте размер с новым pot.", assumptions: "Точная арифметика cash HU, рейк=0. 130 % описывает размер; выгодность требует board, ranges и заданной реакции.", resultKind: .conditionalModel,
              diagram: [.init("Flop после call", "P=50, S=65"), .init("Turn SPR", "65 / 50 = 1,30"), .init("Turn size", "65 / 50 = 130 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t38"),
        .init(id: "E.foundation.t38.sizing-boundary", topicID: .t38, title: "Граница плана по SPR", purpose: .boundary,
              context: ["NLHE cash 6-max, два flop имеют одинаковый P=20 BB и S=80 BB, поэтому SPR=4.", "В первом board A♠K♦2♣, во втором 9♠8♠7♦. Позиции, ranges, рейк и response policy не заданы."],
              question: "Какой вывод о сайзинге корректен?", answer: .choice(options: ["SPR=4 задаёт один обязательный размер", "SPR помогает проверить достижимость плана; board и ranges меняют EV размеров", "Overbet всегда лучше при SPR=4"], correct: 1),
              explanation: ["SPR показывает отношение ресурсов, а не реакцию диапазона.", "Текстура доски и совместимые комбинации меняют fold/call/raise branches.", "Один и тот же размер требует отдельного паспорта для каждого board."],
              typicalError: "Выдать арифметический SPR за универсальную стратегию сайзинга.", term: "План улиц", definition: "Проверяемая последовательность размеров, pot и остатков стека по улицам заданного дерева.", example: "После flop bet/call можно проверить, достигает ли turn ставка остатка стека.", method: "Сначала пересчитайте pot и stacks; затем добавьте board, ranges, позицию, рейк и policy ответов для EV.", assumptions: "Граница условной модели. Проверенной таблицы с полным паспортом здесь нет, поэтому рекомендация размера не формируется.", resultKind: .definitions,
              diagram: [.init("Общее", "P20, S80, SPR4"), .init("Board A", "отдельные ranges"), .init("Board B", "отдельные ranges")], researchAnchor: "nlhe-complete-knowledge-map.md#t38"),

        // MARK: T19 — MDF and bluff:value
        .init(id: "E.foundation.t19.mdf-half-pot", topicID: .t19, title: "MDF для half-pot river", purpose: .concept,
              context: ["NLHE cash 6-max, heads-up river toy game. P=100 BB, b=50 BB; чистые bluffs имеют zero showdown equity.", "Check EV=0, рейк/ничьи/future streets=0. Частота защиты относится к защищаемой массе диапазона, а не к отдельной руке."],
              question: "Введите MDF в процентах с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.mdfPercent(pot: 100, bet: 50), tolerance: 0.01),
              explanation: ["Alpha=b/(P+b)=50/150=1/3.", "MDF=P/(P+b)=100/150=2/3.", "MDF=66,67 % в этой toy-модели."],
              typicalError: "Назвать MDF долей bluff среди ставок или разделить P на P+2b.", term: "MDF", definition: "Доля защищаемой массы, которая продолжает в заданной toy-модели, чтобы чистый bluff был безразличен.", example: "При P100/b50 MDF=66,67 %, а bluff fraction среди ставок равна другой величине 25 %.", method: "Подпишите знаменатель P+b; отдельно храните MDF, alpha, B/V и B/(B+V).", assumptions: "Точная HU river toy-арифметика: zero-equity bluffs, check EV0, рейк0 и дальнейшие raise отсутствуют; continue означает call в этой таблице. Реальный выбор combo требует blockers и ranges.", resultKind: .conditionalModel,
              diagram: [.init("Alpha", "b/(P+b)=50/150"), .init("MDF", "P/(P+b)=100/150"), .init("Знаменатель", "150 BB")], researchAnchor: "nlhe-complete-knowledge-map.md#t19"),
        .init(id: "E.foundation.t19.bluff-mass", topicID: .t19, title: "Bluff:value и bluff fraction", purpose: .transfer,
              context: ["NLHE cash 6-max, HU river toy game. P=100 BB, b=50 BB, рейк=0; value mass V=12 единиц.", "Zero-equity bluff, check EV0. Единицы массы — заданные веса диапазона, они не обязаны быть физическими комбинациями."],
              question: "Сколько единиц bluff B соответствует модели? Введите с точностью до 0,01.", answer: .number(value: 12 * (try! CourseAggressionMath.bluffValueRatio(pot: 100, bet: 50)), tolerance: 0.01),
              explanation: ["Отношение B/V=b/(P+b)=50/150=1/3.", "B=12×1/3=4.", "Bluff fraction среди bets: B/(B+V)=4/16=25 %, она отличается от B/V=1/3."],
              typicalError: "Взять B=3, потому что bluff fraction 25 %, и смешать два разных знаменателя.", term: "Bluff:value и bluff fraction", definition: "B/V сравнивает две массы; B/(B+V) показывает долю bluff внутри всего bet-range.", example: "B4 и V12 дают B/V=1/3, но B/(B+V)=1/4.", method: "Сначала вычислите ratio B/V, умножьте на V, затем отдельно нормируйте B/(B+V).", assumptions: "Точная toy-модель с P100/b50. Эти веса не являются универсальной частотой или готовой стратегией против конкретного соперника.", resultKind: .conditionalModel,
              diagram: [.init("B/V", "50 / 150 = 1/3"), .init("B", "12 × 1/3 = 4"), .init("B/(B+V)", "4 / 16 = 25 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t19"),
        .init(id: "E.foundation.t19.toy-boundary", topicID: .t19, title: "Граница формул MDF", purpose: .boundary,
              context: ["NLHE cash 6-max, flop heads-up. Hero рассматривает draw с текущей equity и возможными ставками turn/river.", "P=100 BB и b=50 BB известны, но check EV и future branches не равны нулю."],
              question: "Какое утверждение корректно?", answer: .choice(options: ["MDF river toy-game сразу даёт точный flop range", "Нужно построить дерево с equity, future EV и response policy", "Достаточно заменить P на flop pot"], correct: 1),
              explanation: ["Формула T19 фиксирует river, zero-equity bluff и check EV0.", "Draw имеет payoff после call и будущие улицы.", "Переход на flop меняет дерево, даже при тех же P и b."],
              typicalError: "Назвать toy MDF универсальной частотой защиты на любой улице.", term: "Toy river game", definition: "Упрощённая игра с явно фиксированными payoff и без будущих ветвей.", example: "На river чистый bluff не имеет showdown equity; draw на flop имеет другую структуру EV.", method: "Проверьте улицу, equity после call, check EV, рейк и future branches до применения формулы.", assumptions: "Понятийная граница. В отсутствие проверенной таблицы полного дерева вывод о частотах остаётся условным.", resultKind: .definitions,
              diagram: [.init("River toy", "zero equity, future=0"), .init("Flop draw", "equity + future branches"), .init("Вывод", "нужно новое EV-дерево")], researchAnchor: "nlhe-complete-knowledge-map.md#t19"),

        // MARK: T20 — bluff-catching
        .init(id: "E.foundation.t20.call-ev", topicID: .t20, title: "EV bluff-catcher", purpose: .concept,
              context: ["NLHE cash 6-max, HU river. До ставки P=100 BB; Villain bet50 BB; Hero call50 BB.", "Hero побеждает только заданную bluff-массу q=30 % и проигрывает value 70 %. Рейк, ничьи и future streets=0.", "Итоговый банк после call=200 BB; q — условный вход диапазона, не наблюдаемая универсальная частота."],
              question: "Введите EV call Hero в BB с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.bluffCatcherEV(bluffShare: 0.3, potBeforeBet: 100, call: 50), tolerance: 0.01),
              explanation: ["Выигрыш против bluff: P+B=150 BB сверх решения о call.", "EV=0,30×150−0,70×50.", "EV=10 BB; fold имеет базу 0 BB."],
              typicalError: "Поставить 200 BB в выигрышную ветвь и второй раз учесть собственный call.", term: "Bluff-catcher", definition: "Рука, которая бьёт заданные bluffs и проигрывает заданному value region.", example: "При call50 выигрыш относительно решения равен 150 BB, а проигрыш равен 50 BB.", method: "Определите, какие классы бьёт Hero; затем используйте q×(P+B)−(1−q)×C с явным P,B,C.", assumptions: "Точное cash HU river-дерево P100/B50/C50, рейк0. q задана учебной моделью; blockers и range construction меняют q.", resultKind: .conditionalModel,
              diagram: [.init("Bluff 30 %", "+150 BB"), .init("Value 70 %", "−50 BB"), .init("EV call", "+10 BB")], researchAnchor: "nlhe-complete-knowledge-map.md#t20"),
        .init(id: "E.foundation.t20.removal-transfer", topicID: .t20, title: "Removal меняет долю bluff", purpose: .transfer,
              context: ["NLHE cash 6-max, HU river: BB Hero A♠Q♣ против BTN Villain, effective stack 100 BB; board Q♦ 7♣ 4♥ 2♠ 9♦. Заданная value-масса: Q♥Q♠ вес6.", "Заданная bluff-масса состоит из шести ветвей веса1: A♠K♦, A♠K♥, J♣T♣, J♥T♥, J♠T♠, J♦T♦. A♠ Hero исключает A♠K♦ и A♠K♥; V остаётся6, B=4.", "Ярлыки bluff и policy — авторские входы этой модели, а не гарантия действий реального Villain. Рейк/ничьи=0."],
              question: "Введите новую bluff fraction B/(B+V) в процентах с точностью до 0,01.", answer: .number(value: try! CourseAggressionMath.ratio(numerator: 4, denominator: 10) * 100, tolerance: 0.01),
              explanation: ["После removal остаётся B=6−2=4.", "Полная bet-масса: B+V=4+6=10.", "Bluff fraction=4/10=40,00 %."],
              typicalError: "Оставить 50 %, используя исходные B6/V6 после удаления двух bluff-единиц.", term: "Removal", definition: "Исключение комбинаций или весов, несовместимых с известными картами.", example: "B4 и V6 нормируются как 4/(4+6)=40 %.", method: "Сначала удалите несовместимую массу в каждом классе, затем заново нормируйте на B+V.", assumptions: "Точная нормировка заданных масс и карт. Реальные blockers требуют явный список combos, weights, board, руку Hero и policy действий.", resultKind: .conditionalModel,
              diagram: [.init("До removal", "B6, V6"), .init("Hero A♠", "исключает 2 B-ветви"), .init("После removal", "B4, V6; B+V=10")], cards: [Card(id: 12), Card(id: 49), Card(id: 36), Card(id: 44), Card(id: 15), Card(id: 0), Card(id: 33)], researchAnchor: "nlhe-complete-knowledge-map.md#t20"),
        .init(id: "E.foundation.t20.defense-boundary", topicID: .t20, title: "Граница MDF для bluff-catcher", purpose: .boundary,
              context: ["NLHE cash 6-max, HU river. P=100 BB, b=50 BB; toy MDF=66,67 % для защищаемой массы.", "Конкретная рука Hero проигрывает всем value и части заданных bluffs. Её blockers, range weights и рейк не заданы."],
              question: "Какой вывод о конкретном call корректен?", answer: .choice(options: ["MDF требует call любой рукой", "Нужны диапазон, blockers, какие bluffs бьёт Hero и рейк", "Сильный ранг карты автоматически делает call прибыльным"], correct: 1),
              explanation: ["MDF описывает защиту массы в ограниченной toy-модели.", "Bluff-catcher должен выигрывать достаточную заданную bluff-массу после removal.", "Рейк и underbluff меняют порог EV конкретного call."],
              typicalError: "Превратить частоту защиты диапазона в обязательный call каждой рукой.", term: "Частота защиты", definition: "Доля защищаемой массы диапазона, продолжающая в заданной модели; она имеет иной знаменатель, чем B/(B+V).", example: "MDF 66,67 % относится к защите диапазона, bluff fraction 25 % — к bet-range при P100/b50.", method: "Разделите три величины: defense mass, B/V и B/(B+V); для руки затем постройте её EV против совместимых классов.", assumptions: "Понятийная граница. Частоты без полного паспорта решения и проверенной таблицы не являются универсальной стратегией.", resultKind: .definitions,
              diagram: [.init("MDF", "защищаемая масса"), .init("B/V", "две массы"), .init("B/(B+V)", "доля внутри bet-range")], researchAnchor: "nlhe-complete-knowledge-map.md#t20")
    ]
}
