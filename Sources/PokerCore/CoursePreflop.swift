import Foundation

public enum CoursePreflopMathError: Error, Equatable, Sendable {
    case invalidAmount
    case nonFiniteResult
}

/// Arithmetic for fixed preflop teaching passports. Strategy inputs stay in the lesson text.
public enum CoursePreflopMath {
    public static func finalPot(contributions: [Double]) throws -> Double {
        guard !contributions.isEmpty, contributions.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw CoursePreflopMathError.invalidAmount
        }
        var total = 0.0
        for contribution in contributions {
            total += contribution
            guard total.isFinite else { throw CoursePreflopMathError.nonFiniteResult }
        }
        return total
    }

    /// Required all-in share as a percentage: call / (pot before call + call).
    public static func allInThresholdPercent(call: Double, potBeforeCall: Double) throws -> Double {
        guard call.isFinite, potBeforeCall.isFinite, call >= 0, potBeforeCall >= 0 else {
            throw CoursePreflopMathError.invalidAmount
        }
        let denominator = potBeforeCall + call
        guard denominator.isFinite else { throw CoursePreflopMathError.nonFiniteResult }
        guard denominator > 0 else { throw CoursePreflopMathError.invalidAmount }
        let result = call / denominator * 100
        guard result.isFinite else { throw CoursePreflopMathError.nonFiniteResult }
        return result
    }

    public static func additionalContribution(to target: Double, alreadyContributed: Double) throws -> Double {
        guard target.isFinite, alreadyContributed.isFinite, target >= 0,
              alreadyContributed >= 0, alreadyContributed <= target else {
            throw CoursePreflopMathError.invalidAmount
        }
        let result = target - alreadyContributed
        guard result.isFinite else { throw CoursePreflopMathError.nonFiniteResult }
        return result
    }
}

public extension FoundationLesson {
    /// T23–T27 build on the published T21/T22 position lessons. Each passport fixes
    /// format, contributions and the calculation moment before a typed answer is checked.
    static let preflopExercises: [FoundationExercise] = [
        // MARK: T23 — BB defence
        .init(id: "E.foundation.t23.bb-price", topicID: .t23, title: "Цена BB против BTN open", purpose: .concept,
              context: ["NLHE cash 6-max, блайнды 0,5/1 bb, ante 0, рейк 0.", "BTN открывает до 2,5 bb; SB уже вложил 0,5 bb; BB уже вложил 1 bb.", "Перед решением BB в банке 4 bb. BB добавляет 1,5 bb; рассматривается all-in модель без будущих ставок."],
              question: "Введите требуемую долю банка для колла BB в процентах с точностью до 0,01.", answer: .number(value: try! CoursePreflopMath.allInThresholdPercent(call: 1.5, potBeforeCall: 4), tolerance: 0.01),
              explanation: ["BB добавляет 2,5 − 1 = 1,5 bb.", "Итоговый банк равен 4 + 1,5 = 5,5 bb.", "Порог all-in: 1,5 / 5,5 = 27,27 %."],
              typicalError: "Делить 1,5 на 4 и забывать фишки собственного колла в итоговом банке.", term: "Защита BB", definition: "Решение BB продолжить против открытия, учитывая уже вложенный блайнд.", example: "Против open 2,5 bb BB добавляет 1,5 bb.", method: "Сначала зафиксируйте банк до решения, затем добавку BB и итоговый банк.", assumptions: "Точный расчёт цены all-in. Cash 6-max, позиции BTN/SB/BB, 100 bb стартовые стеки, остатки покрывают колл, ante и рейк равны 0; будущих улиц нет.", resultKind: .exact,
              diagram: [.init("Банк до BB", "2,5 + 0,5 + 1 = 4 bb"), .init("Колл BB", "1,5 bb"), .init("Знаменатель", "5,5 bb")], researchAnchor: "nlhe-complete-knowledge-map.md#t23"),
        .init(id: "E.foundation.t23.bb-open-three", topicID: .t23, title: "Цена BB против большего открытия", purpose: .transfer,
              context: ["NLHE cash 6-max, блайнды 0,5/1 bb, ante 0, рейк 0.", "BTN открывает до 3 bb; SB вложил 0,5 bb; BB вложил 1 bb.", "Перед решением BB в банке 4,5 bb. BB добавляет 2 bb; модель all-in завершает торговлю."],
              question: "Введите требуемую долю банка для колла BB в процентах с точностью до 0,01.", answer: .number(value: try! CoursePreflopMath.allInThresholdPercent(call: 2, potBeforeCall: 4.5), tolerance: 0.01),
              explanation: ["Банк до действия: 3 + 0,5 + 1 = 4,5 bb.", "Колл BB: 3 − 1 = 2 bb; итоговый банк 6,5 bb.", "2 / 6,5 = 30,77 %."],
              typicalError: "Оставить цену 1,5 bb после изменения open до 3 bb.", term: "Цена колла", definition: "Добавка игрока до текущей ставки, измеренная в bb.", example: "BB уже вложил 1 bb и добавляет 2 bb до ставки 3 bb.", method: "Обновляйте и числитель, и знаменатель после каждого нового размера open.", assumptions: "Точный all-in расчёт в bb; cash 6-max, BTN против BB, 100 bb стартовые стеки, рейк и ante 0.", resultKind: .exact,
              diagram: [.init("Банк до BB", "4,5 bb"), .init("Добавка", "2 bb"), .init("Порог", "2 / 6,5")], researchAnchor: "nlhe-complete-knowledge-map.md#t23"),
        .init(id: "E.foundation.t23.realisation-limit", topicID: .t23, title: "Граница pot odds BB", purpose: .boundary,
              context: ["NLHE cash 6-max: BTN open 2,5 bb, BB рассматривает колл OOP.", "Порог цены уже посчитан в all-in модели; после колла остаются постфлоп-улицы.", "Рейк и диапазон BTN в этом вопросе численно не заданы."],
              question: "Какое утверждение корректно для пограничной руки с сырой equity около порога?", answer: .choice(options: ["Колл обязателен: pot odds полностью выбирают линию", "Нужны рейк, реализация equity OOP и диапазон BTN", "Достаточно знать только две карты BB"], correct: 1),
              explanation: ["Цена колла посчитана точно только для all-in ветви.", "Послефлоповая реализация и рейк меняют EV пограничной руки.", "Без диапазона BTN и параметров cash-стола рекомендация диапазона не задана."],
              typicalError: "Выдать точную дробь pot odds за готовую рекомендацию по диапазону.", term: "Реализация equity", definition: "Доля сырой equity, которую рука превращает в результат при дальнейшем розыгрыше.", example: "BB играет OOP и может реализовать меньшую долю equity, чем в all-in модели.", method: "Отделяйте точную цену all-in от модели будущих улиц и рейка.", assumptions: "Понятийная граница модели; внешняя таблица диапазонов не используется.", resultKind: .definitions,
              diagram: [.init("Точно", "цена all-in"), .init("Нужны входы", "рейк, диапазон, OOP")], researchAnchor: "nlhe-complete-knowledge-map.md#t23"),

        // MARK: T24 — limp and isolation
        .init(id: "E.foundation.t24.dead-money", topicID: .t24, title: "Что уже лежит в банке", purpose: .concept,
              context: ["NLHE cash 6-max, блайнды 0,5/1 bb, ante 0, рейк 0.", "Один игрок лимпит за 1 bb. BTN ещё не действовал.", "До рейза BTN в банке: SB 0,5 bb, BB 1 bb и limp 1 bb."],
              question: "Какие добровольно или принудительно вложенные фишки образуют dead money для решения BTN?", answer: .choice(options: ["Только будущая ставка BTN", "SB 0,5 bb, BB 1 bb и limp 1 bb", "Только limp 1 bb"], correct: 1),
              explanation: ["До действия BTN в банке уже 2,5 bb.", "Эти фишки остаются в банке при рейзе BTN.", "Будущая ставка BTN становится его собственным вкладом, а не уже лежащими деньгами."],
              typicalError: "Назвать dead money только лимп и пропустить блайнды.", term: "Dead money", definition: "Фишки, уже вложенные в банк до текущего решения и доступные для выигрыша.", example: "SB 0,5, BB 1 и limp 1 дают 2,5 bb до рейза BTN.", method: "Отделите взносы до решения от добавки игрока, который сейчас действует.", assumptions: "Точное описание заданного банка; cash 6-max, ante и рейк 0.", resultKind: .definitions,
              diagram: [.init("SB", "0,5 bb"), .init("BB", "1 bb"), .init("Limp", "1 bb"), .init("Банк", "2,5 bb")], researchAnchor: "nlhe-complete-knowledge-map.md#t24"),
        .init(id: "E.foundation.t24.limper-price", topicID: .t24, title: "Цена лимпера после isolation raise", purpose: .transfer,
              context: ["NLHE cash 6-max, блайнды 0,5/1 bb, ante 0, рейк 0.", "SB 0,5 bb + BB 1 bb + limp 1 bb; BTN повышает до 5 bb.", "BB фолдит. Лимпер уже вложил 1 bb и решает колл; после колла банк будет 11,5 bb. Модель all-in без дальнейших ставок."],
              question: "Введите требуемую долю банка для колла лимпера в процентах с точностью до 0,01.", answer: .number(value: try! CoursePreflopMath.allInThresholdPercent(call: 4, potBeforeCall: 7.5), tolerance: 0.01),
              explanation: ["Лимпер добавляет 5 − 1 = 4 bb.", "До его решения в банке 0,5 + 1 + 1 + 5 = 7,5 bb.", "4 / 11,5 = 34,78 %."],
              typicalError: "Считать цену колла 5 bb вместо недостающих 4 bb.", term: "Isolation raise", definition: "Рейз против лимпера с целью уменьшить число соперников или играть инициативно.", example: "BTN повышает с 0 до 5 bb после limp 1 bb.", method: "Запишите отдельной строкой уже внесённый limp и добавку до нового raise-to.", assumptions: "Точный all-in расчёт; позиции BTN и limper, 100 bb стартовые стеки, остатки покрывают колл, рейк 0.", resultKind: .exact,
              diagram: [.init("До колла", "7,5 bb"), .init("Добавка лимпера", "4 bb"), .init("Знаменатель", "11,5 bb")], researchAnchor: "nlhe-complete-knowledge-map.md#t24"),
        .init(id: "E.foundation.t24.limp-limit", topicID: .t24, title: "Граница чтения limp", purpose: .boundary,
              context: ["NLHE cash 6-max, игрок лимпит до рейза.", "Карты, стек, позиция, частоты игрока и число игроков позади не заданы.", "В учебной модели нет лицензированной внешней таблицы диапазонов."],
              question: "Какой вывод о силе limp корректен?", answer: .choice(options: ["Любой limp всегда слабый", "Limp сам по себе не задаёт силу диапазона", "Limp доказывает пару"], correct: 1),
              explanation: ["Одно действие не раскрывает полный диапазон.", "Формат, позиция и привычки игрока задают разные модели.", "Например, SB limp heads-up может быть частью смешанной модели."],
              typicalError: "Превратить ярлык действия в точное чтение конкретной руки.", term: "Смешанная модель", definition: "Модель, где один и тот же класс рук может получать несколько действий с заданными весами.", example: "Одна часть диапазона SB лимпит, другая повышает при тех же блайндах.", method: "Сначала зафиксируйте формат и входы модели; затем проверяйте данные о частотах.", assumptions: "Понятийный контрпример без рекомендации диапазона и без внешнего чарта.", resultKind: .definitions,
              diagram: [.init("Действие", "limp"), .init("Недостающие входы", "позиция, стек, частоты")], researchAnchor: "nlhe-complete-knowledge-map.md#t24"),

        // MARK: T25 — re-raise names and contributions
        .init(id: "E.foundation.t25.bet-names", topicID: .t25, title: "Названия ставок после open", purpose: .concept,
              context: ["NLHE cash 6-max, блайнды 0,5/1 bb, ante 0, рейк 0.", "HJ открывает до 2,5 bb. BTN повышает до 7,5 bb.", "Ни одной добровольной ставки до open не было."],
              question: "Как называется действие BTN?", answer: .choice(options: ["3-bet", "4-bet", "5-bet"], correct: 0),
              explanation: ["Open является первым добровольным рейзом preflop.", "Первое повышение поверх open — 3-bet.", "Следующие полные повышения получили бы названия 4-bet и 5-bet."],
              typicalError: "Считать только число игроков, а не последовательность ставок.", term: "3-bet, 4-bet, 5-bet", definition: "Последовательные повышения preflop: первое re-raise — 3-bet, затем 4-bet и 5-bet.", example: "HJ open, BTN re-raise — это 3-bet BTN.", method: "Отметьте open и каждое следующее повышение в порядке действий.", assumptions: "Точное определение названий; cash 6-max, позиции HJ и BTN, рейк и ante 0.", resultKind: .definitions,
              diagram: [.init("HJ", "open 2,5 bb"), .init("BTN", "raise-to 7,5 bb = 3-bet")], researchAnchor: "nlhe-complete-knowledge-map.md#t25"),
        .init(id: "E.foundation.t25.hj-call-price", topicID: .t25, title: "Цена HJ после 3-bet", purpose: .transfer,
              context: ["NLHE cash 6-max, блайнды 0,5/1 bb, ante 0, рейк 0.", "HJ open 2,5 bb; BTN 3-bet до 7,5 bb; SB и BB уже внесли 0,5 и 1 bb.", "HJ решает колл. До колла HJ в банке 11,5 bb; после его колла — 16,5 bb. Модель all-in завершает торговлю."],
              question: "Введите требуемую долю банка для колла HJ в процентах с точностью до 0,01.", answer: .number(value: try! CoursePreflopMath.allInThresholdPercent(call: 5, potBeforeCall: 11.5), tolerance: 0.01),
              explanation: ["HJ уже вложил 2,5 bb и добавляет 7,5 − 2,5 = 5 bb.", "Знаменатель: 11,5 + 5 = 16,5 bb.", "5 / 16,5 = 30,30 %."],
              typicalError: "Считать в знаменателе только 7,5 bb BTN и пропустить open HJ и блайнды.", term: "Raise-to", definition: "Итоговая сумма вклада игрока после повышения, а не величина добавки.", example: "BTN raise-to 7,5 bb, поэтому HJ добавляет 5 bb к своим 2,5 bb.", method: "Соберите взносы до решения и отдельно найдите недостающую сумму действующего игрока.", assumptions: "Точный all-in расчёт в bb; HJ/BTN, 100 bb стартовые стеки, остатки покрывают колл, рейк 0.", resultKind: .exact,
              diagram: [.init("До колла HJ", "11,5 bb"), .init("Колл HJ", "5 bb"), .init("Знаменатель", "16,5 bb")], researchAnchor: "nlhe-complete-knowledge-map.md#t25"),
        .init(id: "E.foundation.t25-sizing-limit", topicID: .t25, title: "Граница учебного сайзинга", purpose: .boundary,
              context: ["NLHE cash 6-max: HJ open 2,5 bb, BTN рассматривает 3-bet IP.", "Учебный ориентир использует примерно 3× IP и 4× OOP только как условную эвристику.", "Эффективный стек, рейк, диапазоны и игроки позади не заданы численно."],
              question: "Как корректно применить ориентир 3× IP?", answer: .choice(options: ["Как обязательный размер в каждой раздаче", "Как условный вход модели, который требует стека и дерева ответов", "Как доказательство силы диапазона BTN"], correct: 1),
              explanation: ["Размер ставки зависит от заданного дерева и стека.", "Короткий эффективный стек может ограничить размер до all-in.", "Эвристика не образует проверенную таблицу диапазонов."],
              typicalError: "Превратить учебный ориентир сайзинга в универсальное правило.", term: "Условная модель", definition: "Расчёт с явно заданными входами, чей вывод относится только к этим входам.", example: "3× IP описывает один учебный паспорт, а не все cash-столы.", method: "Покажите формат, позиции, стек, open и ответные ветви до выбора размера.", assumptions: "Понятийный контрпример; внешние чарты не используются, стратегическая сила не заявляется.", resultKind: .conditionalModel,
              diagram: [.init("Входы", "формат, позиция, стек, open"), .init("Вывод", "условный размер")], researchAnchor: "nlhe-complete-knowledge-map.md#t25"),

        // MARK: T26 — cold call and squeeze
        .init(id: "E.foundation.t26.squeeze-name", topicID: .t26, title: "Распознать squeeze", purpose: .concept,
              context: ["NLHE cash 6-max, блайнды 0,5/1 bb, ante 0, рейк 0.", "CO открывает до 2,5 bb, BTN cold call 2,5 bb, SB повышает до 11 bb.", "BB ещё не действовал; SB до решения уже вложил 0,5 bb."],
              question: "Как называется рейз SB?", answer: .choice(options: ["Cold call", "Squeeze", "Limp"], correct: 1),
              explanation: ["Cold call BTN уже создал ветвь open + call.", "3-bet SB поверх open и хотя бы одного call называется squeeze.", "SB добавляет до 11 bb, но название действия определяется последовательностью."],
              typicalError: "Назвать squeeze обычным open или cold call и потерять порядок действий.", term: "Cold call и squeeze", definition: "Cold call — добровольный колл чужого open; squeeze — 3-bet после open и одного или нескольких call.", example: "CO open, BTN call, SB raise — squeeze SB.", method: "Сначала отметьте open и call, затем проверьте, является ли следующий рейз 3-bet.", assumptions: "Точное определение последовательности; cash 6-max, рейк и ante 0.", resultKind: .definitions,
              diagram: [.init("CO", "open 2,5"), .init("BTN", "cold call 2,5"), .init("SB", "raise-to 11 = squeeze")], researchAnchor: "nlhe-complete-knowledge-map.md#t26"),
        .init(id: "E.foundation.t26.btn-squeeze-price", topicID: .t26, title: "Цена BTN против squeeze", purpose: .transfer,
              context: ["NLHE cash 6-max, блайнды 0,5/1 bb, ante 0, рейк 0.", "CO open 2,5 bb, BTN cold call 2,5 bb, SB squeeze до 11 bb; BB и CO фолдят.", "BTN уже вложил 2,5 bb. До решения BTN в банке 17 bb; его колл 8,5 bb даёт итоговый банк 25,5 bb. Модель all-in завершает торговлю."],
              question: "Введите требуемую долю банка для колла BTN в процентах с точностью до 0,01.", answer: .number(value: try! CoursePreflopMath.allInThresholdPercent(call: 8.5, potBeforeCall: 17), tolerance: 0.01),
              explanation: ["BTN добавляет 11 − 2,5 = 8,5 bb.", "До решения: CO 2,5 + BTN 2,5 + SB 11 + BB 1 = 17 bb.", "8,5 / 25,5 = 33,33 %."],
              typicalError: "Забыть 1 bb BB после его фолда: вложенные фишки остаются в банке.", term: "Вклад до решения", definition: "Сумма фишек, уже оставшаяся в банке к моменту выбора действия.", example: "Фолд BB не возвращает его обязательный блайнд.", method: "Сложите все внесённые фишки, включая фолд, затем добавьте цену действующего игрока в знаменатель.", assumptions: "Точный all-in расчёт в bb; cash 6-max, позиции CO/BTN/SB/BB, 100 bb стартовые стеки, рейк 0.", resultKind: .exact,
              diagram: [.init("Банк до BTN", "17 bb"), .init("Добавка BTN", "8,5 bb"), .init("Знаменатель", "25,5 bb")], researchAnchor: "nlhe-complete-knowledge-map.md#t26"),
        .init(id: "E.foundation.t26.range-limit", topicID: .t26, title: "Граница вывода из cold call", purpose: .boundary,
              context: ["NLHE cash 6-max: BTN cold call против CO open.", "Карты BTN, его частоты, рейк, стек и модель диапазона не заданы.", "Задача не использует лицензированную таблицу диапазонов."],
              question: "Какой вывод о диапазоне BTN корректен?", answer: .choice(options: ["В cold-call range никогда нет сильных рук", "Диапазон требует явно заданной модели или данных о частотах", "Одна линия точно раскрывает две карты BTN"], correct: 1),
              explanation: ["Одна линия действия не фиксирует все физические комбинации.", "Сильные руки могут встречаться в call и 3-bet ветвях при смешанной модели.", "Для вывода нужны позиции, стек, рейк и заданные веса."],
              typicalError: "Исключить все сильные руки из range по одному наблюдению.", term: "Вывод о диапазоне", definition: "Условное заключение о множестве рук из действий и заданной модели.", example: "Одинаковый cold call может иметь разные веса в разных полях и стеках.", method: "Покажите входы модели и нормировку весов; без них оставьте вывод понятийным.", assumptions: "Контрпример модели; стратегические рекомендации и внешние чарты отсутствуют.", resultKind: .conditionalModel,
              diagram: [.init("Наблюдение", "cold call"), .init("Требуются", "веса, позиции, стек, рейк")], researchAnchor: "nlhe-complete-knowledge-map.md#t26"),

        // MARK: T27 — short stacks and chip EV
        .init(id: "E.foundation.t27.shove-addition", topicID: .t27, title: "Добавка SB до shove", purpose: .concept,
              context: ["MTT 6-max, блайнды 10/20, ante 2 от каждого: forced pot 42. BTN открывает до 45 фишек; перед SB решением банк 87.", "SB начал раздачу с 302, после ante 2 и SB 10 у него осталось 290.", "SB объявляет shove до 300; ICM и выплаты в этом расчёте не используются."],
              question: "Сколько фишек SB добавляет до shove?", answer: .number(value: try! CoursePreflopMath.additionalContribution(to: 300, alreadyContributed: 10), tolerance: 0),
              explanation: ["Ante 2 уже уменьшил стек SB до обязательного блайнда.", "SB уже внёс 10 фишек как малый блайнд.", "До итогового вклада 300 он добавляет 300 − 10 = 290."],
              typicalError: "Вычесть ante из вклада в банк дважды или считать shove добавкой 300.", term: "Shove", definition: "All-in до всего доступного вклада игрока в текущей раздаче.", example: "SB уже внёс 10 и доводит общий вклад до 300.", method: "Разделите стартовый стек, обязательные списания и уже внесённый вклад на текущей улице.", assumptions: "Точный учёт фишек MTT 6-max; ante 2 от каждого, ICM и выплаты исключены, результат относится к chip EV.", resultKind: .exact,
              diagram: [.init("Стек SB", "302 → 300 после ante"), .init("Уже в банке", "SB 10"), .init("Добавка", "290")], researchAnchor: "nlhe-complete-knowledge-map.md#t27"),
        .init(id: "E.foundation.t27.final-pot", topicID: .t27, title: "Итоговый банк после call", purpose: .transfer,
              context: ["MTT 6-max, блайнды 10/20, ante 2 от каждого. BTN open 45; SB shove до 300; BB фолдит.", "BTN коллирует, добавляя 255 до общего вклада 300.", "Итоговые вклады в банк: все ante 12, BB 20, BTN 300, SB 300. ICM и выплаты исключены."],
              question: "Введите итоговый банк в фишках.", answer: .number(value: try! CoursePreflopMath.finalPot(contributions: [12, 20, 300, 300]), tolerance: 0),
              explanation: ["Все ante дают 6 × 2 = 12.", "BB фолдит, но его 20 остаются в банке.", "12 + 20 + 300 + 300 = 632 фишки."],
              typicalError: "Убрать BB 20 из банка после фолда или добавить BTN open 45 второй раз.", term: "Итоговый банк", definition: "Сумма всех фактически внесённых и не возвращённых фишек после выбранных действий.", example: "Вклад BTN 300 уже содержит его исходный open 45.", method: "Сложите итоговый вклад каждого участника один раз; фолд не возвращает покрытые фишки.", assumptions: "Точный учёт chip EV MTT; 6-max, ante 2, ICM и выплаты исключены, возврата непокрытой ставки нет.", resultKind: .exact,
              diagram: [.init("Ante 6 × 2", "12"), .init("BB folded", "20 остаются"), .init("BTN + SB", "300 + 300"), .init("Банк", "632")], researchAnchor: "nlhe-complete-knowledge-map.md#t27"),
        .init(id: "E.foundation.t27.icm-limit", topicID: .t27, title: "Граница chip EV resteal", purpose: .boundary,
              context: ["MTT 6-max, 10/20, ante 2. BTN open 45; SB shove до 300; перед shove в банке 87.", "В крайней учебной модели BB всегда фолдит, BTN покрывает shove, у SB нулевая equity при колле BTN.", "Рассматривается bubble с выплатами, но ICM-состояния стеков и призов не заданы."],
              question: "Можно ли назвать порог 290 / (87 + 290) = 76,92 % денежным EV на bubble?", answer: .choice(options: ["Да, chip EV всегда равен денежному EV", "Нет, для bubble нужны ICM и состояния выплат", "Да, если SB уже вложил блайнд"], correct: 1),
              explanation: ["76,92 % — точный chip-EV порог только в заданной нулевой модели showdown equity.", "Bubble меняет ценность фишек через выплаты и стеки.", "Для денежного EV нужны ICM terminal states, а не одна дробь банка."],
              typicalError: "Перенести chip-EV порог в турнирную выплатную ситуацию.", term: "Resteal и chip EV", definition: "Resteal — re-shove против open; chip EV измеряет ожидаемые фишки без оценки турнирных выплат.", example: "Порог 290 / 377 относится к ветви fold при нулевой equity, а не к ICM.", method: "Сначала выберите метрику: chip EV или ICM. Затем задайте equity, range колла и все ветви дерева.", assumptions: "Граница модели: MTT 6-max, нулевая showdown equity как искусственный пример, без рекомендации shove-диапазона.", resultKind: .conditionalModel,
              diagram: [.init("Риск", "290"), .init("Fold-ветвь", "87 + 290 = 377"), .init("Порог chip EV", "76,92 %"), .init("Bubble", "нужны ICM и выплаты")], researchAnchor: "nlhe-complete-knowledge-map.md#t27")
    ]
}
