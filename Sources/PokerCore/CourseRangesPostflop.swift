import Foundation

/// Checked arithmetic for the fixed, disclosed teaching models in M08 and M09.
/// Lesson prose supplies labels and assumptions; Swift values remain the grading source.
public enum CourseRangesMathError: Error, Equatable, Sendable {
    case invalidProbability
    case invalidAmount
    case zeroNormalizer
    case nonFiniteResult
}

public enum CourseRangesMath {
    public static func posteriorPercent(
        priorTarget: Double,
        likelihoodTarget: Double,
        priorOther: Double,
        likelihoodOther: Double
    ) throws -> Double {
        let values = [priorTarget, likelihoodTarget, priorOther, likelihoodOther]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
              abs(priorTarget + priorOther - 1) < 1e-12 else {
            throw CourseRangesMathError.invalidProbability
        }
        let normalizer = priorTarget * likelihoodTarget + priorOther * likelihoodOther
        guard normalizer.isFinite else { throw CourseRangesMathError.nonFiniteResult }
        guard normalizer > 0 else { throw CourseRangesMathError.zeroNormalizer }
        let result = 100 * priorTarget * likelihoodTarget / normalizer
        guard result.isFinite else { throw CourseRangesMathError.nonFiniteResult }
        return result
    }

    public static func normalizerPercent(
        priorFirst: Double,
        likelihoodFirst: Double,
        priorSecond: Double,
        likelihoodSecond: Double
    ) throws -> Double {
        let values = [priorFirst, likelihoodFirst, priorSecond, likelihoodSecond]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
              abs(priorFirst + priorSecond - 1) < 1e-12 else {
            throw CourseRangesMathError.invalidProbability
        }
        let result = 100 * (priorFirst * likelihoodFirst + priorSecond * likelihoodSecond)
        guard result.isFinite else { throw CourseRangesMathError.nonFiniteResult }
        return result
    }

    public static func weightedCombinations(count: Double, weight: Double) throws -> Double {
        guard count.isFinite, weight.isFinite, count >= 0, weight >= 0, weight <= 1 else {
            throw CourseRangesMathError.invalidAmount
        }
        let result = count * weight
        guard result.isFinite else { throw CourseRangesMathError.nonFiniteResult }
        return result
    }

    public static func percent(numerator: Double, denominator: Double) throws -> Double {
        guard numerator.isFinite, denominator.isFinite, numerator >= 0, denominator > 0 else {
            throw CourseRangesMathError.invalidAmount
        }
        let result = numerator / denominator * 100
        guard result.isFinite else { throw CourseRangesMathError.nonFiniteResult }
        return result
    }

    /// Threshold for an all-in call in a one-pot, no-rake model.
    public static func callThresholdPercent(call: Double, finalPot: Double) throws -> Double {
        guard call.isFinite, finalPot.isFinite, call >= 0, finalPot > 0, call <= finalPot else {
            throw CourseRangesMathError.invalidAmount
        }
        return try percent(numerator: call, denominator: finalPot)
    }

    public static func riverBetEV(equity: Double, finalPot: Double, bet: Double) throws -> Double {
        guard equity.isFinite, (0...1).contains(equity), finalPot.isFinite, bet.isFinite,
              finalPot > 0, bet >= 0, bet <= finalPot else { throw CourseRangesMathError.invalidAmount }
        let value = equity * finalPot - bet
        guard value.isFinite else { throw CourseRangesMathError.nonFiniteResult }
        return value
    }

    /// Fold rate needed by a zero-showdown-equity river bluff in the stated model.
    public static func bluffFoldThresholdPercent(pot: Double, bet: Double) throws -> Double {
        guard pot.isFinite, bet.isFinite, pot >= 0, bet > 0 else {
            throw CourseRangesMathError.invalidAmount
        }
        return try percent(numerator: bet, denominator: pot + bet)
    }
}

public extension FoundationLesson {
    /// New M08–M09 lessons. Every strategic list is an authored conditional model
    /// with a complete passport in its context and assumptions.
    static let rangesPostflopExercises: [FoundationExercise] = [
        // MARK: T17 — Bayes and weighted ranges
        .init(id: "E.foundation.t17.normalizer", topicID: .t17, title: "Знаменатель после ставки", purpose: .concept,
              context: ["NLHE cash 6-max, heads-up river; стек и размер ставки не меняют эту задачу.", "До ставки учебный диапазон Villain: value 40 %, bluff 60 %.", "Заданная политика: P(bet|value)=80 %, P(bet|bluff)=20 %. Вероятности — входы модели, не статистика поля."],
              question: "Введите знаменатель P(bet) в процентах, округляя до 0,01.", answer: .number(value: try! CourseRangesMath.normalizerPercent(priorFirst: 0.4, likelihoodFirst: 0.8, priorSecond: 0.6, likelihoodSecond: 0.2), tolerance: 0.01),
              explanation: ["Масса ставки от value: 0,40 × 0,80 = 0,32.", "Масса ставки от bluff: 0,60 × 0,20 = 0,12.", "Знаменатель: 0,32 + 0,12 = 0,44 = 44,00 %."],
              typicalError: "Сложить likelihood 80 % и 20 % без весов prior.", term: "Знаменатель Байеса", definition: "Полная вероятность наблюдаемого действия по всем заданным классам.", example: "В этой модели ставка имеет массу 44 %.", method: "Умножьте prior каждого класса на его likelihood действия и сложите результаты.", assumptions: "Два взаимоисключающих класса с суммарным prior 100 %; единица измерения — доля диапазона; округление до 0,01 п.п.", resultKind: .conditionalModel,
              diagram: [.init("Value", "40 % × 80 % = 32 %"), .init("Bluff", "60 % × 20 % = 12 %"), .init("P(bet)", "44 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t17"),
        .init(id: "E.foundation.t17.changed-likelihood", topicID: .t17, title: "Новая вероятность bluff", purpose: .transfer,
              context: ["NLHE cash 6-max, heads-up river; банк 30 BB, ставка 20 BB.", "Prior: value 40 %, bluff 60 %. P(bet|value)=80 %.", "Изменённый вход условной модели: P(bet|bluff)=40 %. Карты и реальная частота поля не заданы."],
              question: "Введите P(value|bet) в процентах, округляя до 0,01.", answer: .number(value: try! CourseRangesMath.posteriorPercent(priorTarget: 0.4, likelihoodTarget: 0.8, priorOther: 0.6, likelihoodOther: 0.4), tolerance: 0.01),
              explanation: ["Value-масса: 0,40 × 0,80 = 0,32.", "Общая bet-масса: 0,32 + 0,60 × 0,40 = 0,56.", "Posterior: 0,32 / 0,56 = 57,14 %."],
              typicalError: "Оставить прежний ответ 72,73 %, хотя likelihood bluff изменился.", term: "Posterior", definition: "Нормированная масса класса после наблюдаемого действия.", example: "При более частом bluff-bet доля value среди ставок уменьшается.", method: "Пересчитайте знаменатель для новых входов и разделите массу нужного класса на него.", assumptions: "Политика ставок задана условием; 20 BB и 30 BB задают контекст линии, но в формуле posterior не используются; округление до 0,01 п.п.", resultKind: .conditionalModel,
              diagram: [.init("Value bet", "32 %"), .init("Bluff bet", "24 %"), .init("Value после bet", "32 / 56 = 57,14 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t17"),
        .init(id: "E.foundation.t17.boundary", topicID: .t17, title: "Граница обновления", purpose: .boundary,
              context: ["NLHE cash 6-max, CO против BTN, flop A♠ 7♦ 2♣, effective stack 100 BB.", "BTN сделал ставку 4 BB в банк 8 BB. Один эпизод не задаёт вероятность действия по классам."],
              question: "Какие входы нужны для следующего корректного обновления на turn?", answer: .choice(options: ["Новая доска, совместимые комбинации, prior и заданные likelihood действий", "Только размер ставки 4 BB", "Открытые карты BTN"], correct: 0),
              explanation: ["Turn меняет совместимые комбинации через removal.", "Нужны исходные веса и условная политика действия для оставшихся классов.", "Собственная карта BTN остаётся скрытой; её нельзя подставлять в модель."],
              typicalError: "Назвать один наблюдённый bet измеренной вероятностью bluff.", term: "Модель обновления", definition: "Явный набор prior, классов, совместимых карт и likelihood для конкретного наблюдения.", example: "После новой карты доски часть комбинаций исключается до нормировки весов.", method: "Сначала обновите список комбинаций по известным картам, затем примените только заданные likelihood.", assumptions: "Задача проверяет границу модели; стратегические частоты получают внешний источник или отдельную выборку.", resultKind: .definitions,
              diagram: [.init("До turn", "prior + policy"), .init("Turn", "removal"), .init("После", "нормировка")], researchAnchor: "nlhe-complete-knowledge-map.md#t17"),

        // MARK: T32 — labels for explicitly listed conditional ranges
        .init(id: "E.foundation.t32.hard-cap", topicID: .t32, title: "Hard-cap в условном списке", purpose: .concept,
              context: ["NLHE cash 6-max, BTN открыл 2,5 BB, BB сделал 3-bet до 10 BB, effective stack 100 BB.", "Учебная модель call BTN: AA вес 0, KK вес 0, QQ вес 1, AQs вес 1, KQs вес 1.", "Список описывает только эту модель линии; он не является чартом поля."],
              question: "Какой ярлык точнее описывает AA в диапазоне call BTN?", answer: .choice(options: ["Hard-capped по AA", "Soft-capped по AA", "Uncapped по AA"], correct: 0),
              explanation: ["Вес AA равен нулю, поэтому AA исключено из заданного списка.", "Soft-cap уменьшал бы вес AA, сохраняя положительную массу.", "Uncapped оставлял бы AA возможной комбинацией."],
              typicalError: "Называть диапазон capped, когда сильной руке просто назначен меньший положительный вес.", term: "Hard-cap", definition: "Явное исключение части верхнего диапазона с весом 0 в заданной модели.", example: "AA с весом 0 после call 3-bet — hard-cap по AA.", method: "Читайте веса списка: 0 означает исключение, положительный вес означает возможность.", assumptions: "Префлоп, до учёта собственных карт; классы и веса заданы авторской условной моделью. Позиции, стек и линия фиксированы.", resultKind: .conditionalModel,
              diagram: [.init("AA", "вес 0"), .init("KK", "вес 0"), .init("QQ / AQs / KQs", "вес 1")], researchAnchor: "nlhe-complete-knowledge-map.md#t32"),
        .init(id: "E.foundation.t32.soft-cap-mass", topicID: .t32, title: "Масса soft-cap", purpose: .transfer,
              context: ["NLHE cash 6-max, BTN открыл 2,5 BB, BB сделал 3-bet до 10 BB, effective stack 100 BB.", "Исходно AA содержит 6 физических комбинаций.", "В учебной модели call BTN оставляет AA с весом 0,25; остальные классы здесь не нужны."],
              question: "Сколько взвешенных комбинаций AA остаётся? Введите число с точностью до 0,01.", answer: .number(value: try! CourseRangesMath.weightedCombinations(count: 6, weight: 0.25), tolerance: 0.01),
              explanation: ["Физических AA-комбинаций: 6.", "Вес 0,25 сохраняет четверть этой массы.", "6 × 0,25 = 1,50 взвешенной комбинации."],
              typicalError: "Округлить 1,5 до одной физической комбинации и потерять смысл веса.", term: "Soft-cap", definition: "Уменьшение веса сильной части диапазона без её полного исключения.", example: "AA с весом 0,25 даёт массу 1,5 из шести комбинаций.", method: "Умножьте число физических комбинаций на заданный вес; единица результата — взвешенная комбинация.", assumptions: "Вес 0,25 — вход авторской модели линии; итог 1,50 является точной арифметикой внутри неё.", resultKind: .conditionalModel,
              diagram: [.init("AA физически", "6 combos"), .init("Вес", "0,25"), .init("Масса", "1,50 combos")], researchAnchor: "nlhe-complete-knowledge-map.md#t32"),
        .init(id: "E.foundation.t32.polarized-boundary", topicID: .t32, title: "Граница ярлыка polarized", purpose: .boundary,
              context: ["NLHE cash 6-max, river, BB OOP ставит 20 BB в банк 30 BB против BTN, effective stack 60 BB.", "Доска A♦ A♣ 7♦ 2♥ 3♣. Авторская модель: каре {A♠A♥} и bluff {K♠Q♠}; классы JJ и TT имеют вес 0.", "Этот список назначен только данной линии и данной доске."],
              question: "Какой ярлык подходит списку ставки BB?", answer: .choice(options: ["Polarized: очень сильные руки и bluff, без средних пар", "Linear: все сильные и средние руки подряд", "Свойство любой ставки OOP"], correct: 0),
              explanation: ["В списке есть верхняя часть и bluff-часть.", "Средние пары исключены, поэтому список не линейный.", "Ярлык относится к явно заданному списку, а не ко всем действиям OOP."],
              typicalError: "Выводить состав диапазона из одного размера ставки без списка рук и весов.", term: "Polarized range", definition: "Диапазон, в котором модель оставляет очень сильные руки и bluff-ветвь, исключая часть средних рук.", example: "Nuts плюс K♠Q♠ bluff при нулевом весе JJ и TT.", method: "Проверьте, содержит ли список одновременно верхнюю и bluff-часть, затем прочитайте веса средних рук.", assumptions: "Состав списков и политика ставки заданы условно; показатель силы игры из этой классификации не выводится.", resultKind: .conditionalModel,
              diagram: [.init("Value", "A♠A♥"), .init("Средняя часть", "JJ, TT: вес 0"), .init("Bluff", "K♠Q♠")], researchAnchor: "nlhe-complete-knowledge-map.md#t32"),

        .init(id: "E.foundation.t32.linear", topicID: .t32, title: "Линейный список и верх диапазона", purpose: .concept,
              context: ["NLHE cash 6-max, BTN open 2,5 BB, BB рассматривает 3-bet до 10 BB, эффективный стек 100 BB, ante 0, рейк модели 0.", "Авторская учебная шкала классов: AA → KK → QQ → JJ → TT → 99 → 72o. Это заданный порядок для классификации.", "Модель 3-bet BB включает AA, KK, QQ и JJ с весом 1; остальные классы имеют вес 0. Собственные карты ещё не фиксированы."],
              question: "Какие ярлыки описывают этот список по заданной шкале?", answer: .choice(options: ["Линейный и uncapped: верхняя последовательность, AA остаётся", "Полярный: верх и блеф 72o", "Hard-capped по AA"], correct: 0),
              explanation: ["Модель берёт подряд верхнюю часть заданной шкалы.", "AA имеет положительный вес: верх диапазона сохранён, то есть uncapped.", "Рекомендация 3-bet не выводится: здесь проверяется чтение заданного списка."],
              typicalError: "Назвать каждый узкий список полярным, не проверив наличие нижней блефовой части.", term: "Linear и uncapped", definition: "Линейный список берёт последовательную верхнюю часть принятой шкалы; uncapped сохраняет её верх.", example: "AA/KK/QQ/JJ по заданному порядку — линейный uncapped список.", method: "Прочитайте шкалу, веса верхних, средних и нижних классов, затем назначьте ярлыки.", assumptions: "Классификация относится к авторской шкале и списку. Диапазон игры требует отдельной проверки модели, позиций, стека, рейка и политики.", resultKind: .conditionalModel,
              chart: [.init("AA", "1"), .init("KK", "1"), .init("QQ", "1"), .init("JJ", "1"), .init("TT/99", "0"), .init("72o", "0")], researchAnchor: "nlhe-complete-knowledge-map.md#t32"),

        // MARK: T29 — board texture
        .init(id: "E.foundation.t29.tags", topicID: .t29, title: "Теги текстуры", purpose: .concept,
              context: ["NLHE cash 6-max, BTN против BB, flop 9♠ 8♠ 7♦, pot 8 BB, effective stack 96 BB.", "Диапазоны и решения игроков не заданы: задача описывает только открытые карты."],
              question: "Какое описание flop точное?", answer: .choice(options: ["Неспаренный, two-tone, сильно связный", "Спаренный, rainbow, несвязный", "Monotone и спаренный"], correct: 0),
              explanation: ["9, 8 и 7 — разные ранги, поэтому доска неспаренная.", "Две пики и одна бубна образуют two-tone.", "Соседние ранги 7–8–9 делают доску сильно связной."],
              typicalError: "Называть доску «мокрой» без проверки рангов и мастей.", term: "Текстура доски", definition: "Описание рангов, мастей, парности и связности общих карт.", example: "9♠ 8♠ 7♦ — two-tone и связная текстура.", method: "Отдельно отметьте пары рангов, число мастей и расстояния между рангами.", assumptions: "Теги карт точны; последствия для диапазонов требуют их явного списка и отдельной модели.", resultKind: .definitions,
              diagram: [.init("Ранги", "9–8–7"), .init("Масти", "♠ ♠ ♦"), .init("Теги", "unpaired / two-tone / connected")], cards: [Card(id: 7), Card(id: 6), Card(id: 31)], researchAnchor: "nlhe-complete-knowledge-map.md#t29"),
        .init(id: "E.foundation.t29.straight-completers", topicID: .t29, title: "Два ранга для стрита", purpose: .transfer,
              context: ["NLHE cash 6-max, BTN против BB, flop 9♠ 8♠ 7♦, pot 8 BB, effective stack 96 BB.", "Hero держит A♣ T♦. Рассматривается только точное свойство пяти карт на turn; диапазоны и ставки не заданы."],
              question: "Сколько разных рангов turn завершают Hero straight?", answer: .number(value: 2, tolerance: 0),
              explanation: ["6x создаёт 6–7–8–9–T.", "Jx создаёт 7–8–9–T–J.", "Ранги-завершители: 6 и J, всего два."],
              typicalError: "Считать масти вместо рангов, когда вопрос просит число разных рангов.", term: "Завершитель стрита", definition: "Ранг следующей карты, который позволяет собрать последовательность из пяти рангов.", example: "Для A♣T♦ на 9–8–7 подходят 6 и J.", method: "Составьте все пятёрки с имеющимися рангами и выпишите недостающий ранг каждой последовательности.", assumptions: "Единица ответа — ранг, а не число физических карт; точный расчёт по открытым картам.", resultKind: .exact,
              diagram: [.init("Имеющиеся ранги", "7–8–9–T"), .init("Turn 6", "6–7–8–9–T"), .init("Turn J", "7–8–9–T–J")], cards: [Card(id: 7), Card(id: 6), Card(id: 31), Card(id: 51), Card(id: 34)], researchAnchor: "nlhe-complete-knowledge-map.md#t29"),
        .init(id: "E.foundation.t29.range-boundary", topicID: .t29, title: "Граница текстуры", purpose: .boundary,
              context: ["NLHE cash 6-max, BTN против BB, flop K♣ 7♦ 2♥, pot 8 BB, effective stack 96 BB.", "Карты доски известны. Диапазоны BTN и BB, их веса и линия ставок не заданы."],
              question: "Какой дополнительный вход нужен, чтобы сравнить покрытие доски двух игроков?", answer: .choice(options: ["Явные диапазоны с весами после линии", "Только название текстуры rainbow", "Случайная карта river"], correct: 0),
              explanation: ["Одна и та же доска соединяется с разными списками рук по-разному.", "Покрытие требует комбинаций и их весов после уже совершённых действий.", "Rainbow сам по себе не даёт распределение рук игроков."],
              typicalError: "Превратить тег доски в готовую рекомендацию по ставке.", term: "Покрытие доски", definition: "Наличие в заданном диапазоне комбинаций, сильно соединяющихся с конкретной доской.", example: "Низкие connected руки могут быть в одном диапазоне и отсутствовать в другом.", method: "Сначала фиксируйте board, затем перечисляйте совместимые комбинации каждого диапазона и их веса.", assumptions: "Задача устанавливает границу: текстура — точное описание карт; стратегический вывод требует модели диапазонов.", resultKind: .definitions,
              diagram: [.init("Board", "K♣ 7♦ 2♥"), .init("Нужны", "ranges + weights"), .init("Вывод", "после списка combos")], cards: [Card(id: 50), Card(id: 31), Card(id: 13)], researchAnchor: "nlhe-complete-knowledge-map.md#t29"),

        // MARK: T39 — order after the flop
        .init(id: "E.foundation.t39.ip", topicID: .t39, title: "Кто действует IP", purpose: .concept,
              context: ["NLHE cash 6-max, CO открыл 2,5 BB, BTN колл; SB, BB, UTG и HJ сфолдили.", "Flop K♣ 7♦ 2♥, pot 6,5 BB, effective stack 97,5 BB. Активны только CO и BTN."],
              question: "Кто действует последним на flop?", answer: .choice(options: ["BTN", "CO", "Сфолдивший BB"], correct: 0),
              explanation: ["После flop порядок идёт от первого активного места слева от BTN.", "CO действует раньше BTN.", "BTN остаётся последним активным игроком и находится IP."],
              typicalError: "Считать preflop-агрессора автоматически IP.", term: "IP", definition: "Позиция игрока, который действует последним на текущей postflop улице.", example: "CO open и BTN call heads-up: BTN IP на flop.", method: "Уберите сфолдившие места и прочитайте postflop порядок среди активных игроков.", assumptions: "Обычный порядок NLHE 6-max; сила рук, диапазоны и ставки не участвуют в определении IP.", resultKind: .definitions,
              diagram: [.init("Активные", "CO → BTN"), .init("Первый postflop", "CO"), .init("Последний", "BTN (IP)")], cards: [Card(id: 50), Card(id: 31), Card(id: 13)], researchAnchor: "nlhe-complete-knowledge-map.md#t39"),
        .init(id: "E.foundation.t39.call-threshold", topicID: .t39, title: "Цена колла IP", purpose: .transfer,
              context: ["NLHE cash 6-max, CO OOP против BTN IP на flop K♣ 7♦ 2♥.", "В банке 8 BB; CO ставит 3 BB; BTN рассматривает колл 3 BB; effective stack 92 BB.", "Один банк, без рейка и будущих ставок: это точный порог all-in/check-down модели."],
              question: "Введите требуемую equity BTN для колла в процентах, округляя до 0,01.", answer: .number(value: try! CourseRangesMath.callThresholdPercent(call: 3, finalPot: 14), tolerance: 0.01),
              explanation: ["После колла итоговый банк: 8 + 3 + 3 = 14 BB.", "Цена BTN: 3 BB.", "Порог: 3 / 14 = 21,43 %."],
              typicalError: "Делить 3 BB только на исходный банк 8 BB.", term: "Порог колла", definition: "Доля итогового банка, равная цене колла в модели без будущих выплат.", example: "3 BB / 14 BB = 21,43 %.", method: "Сложите текущий банк, ставку соперника и свою доплату, затем разделите доплату на итог.", assumptions: "Единицы — BB; без рейка, будущих ставок и side pot; позиция не меняет эту арифметику; округление до 0,01 п.п.", resultKind: .exact,
              diagram: [.init("Банк до ставки", "8 BB"), .init("Колл / итог", "3 / 14 BB"), .init("Порог", "21,43 %")], cards: [Card(id: 50), Card(id: 31), Card(id: 13)], researchAnchor: "nlhe-complete-knowledge-map.md#t39"),
        .init(id: "E.foundation.t39.folded-button", topicID: .t39, title: "Сфолдивший BTN", purpose: .boundary,
              context: ["NLHE cash 6-max, CO открыл, BTN сфолдил, BB колл; UTG, HJ и SB сфолдили.", "Flop Q♠ 6♦ 2♣, pot 6 BB, effective stack 97 BB. Активны только CO и BB."],
              question: "Кто действует первым на flop?", answer: .choice(options: ["BB", "CO", "BTN, потому что это кнопка"], correct: 0),
              explanation: ["BTN вышел из раздачи и пропускается.", "Среди активных игроков BB находится раньше CO в postflop порядке.", "CO действует вторым и является IP в этой heads-up раздаче."],
              typicalError: "Сохранять порядок игрока, который уже сфолдил.", term: "Активный игрок", definition: "Участник, не сфолдивший карты и поэтому сохраняющий право действия.", example: "Сфолдивший BTN не может быть IP в банке CO против BB.", method: "Перед каждой улицей исключите сфолдившие места, затем примените порядок к оставшимся игрокам.", assumptions: "Обычный порядок NLHE 6-max; задача проверяет порядок действий, без стратегических рекомендаций.", resultKind: .definitions,
              diagram: [.init("Сфолдили", "UTG, HJ, BTN, SB"), .init("Активны", "BB → CO"), .init("Первый", "BB")], cards: [Card(id: 10), Card(id: 30), Card(id: 39)], researchAnchor: "nlhe-complete-knowledge-map.md#t39"),

        // MARK: T34 — c-bet and delayed c-bet
        .init(id: "E.foundation.t34.delayed", topicID: .t34, title: "Ставка после check-through", purpose: .concept,
              context: ["NLHE cash 6-max, BTN — последний агрессор префлопа, BB колл; на указанной улице осталось 100 BB эффективного стека.", "Flop K♣ 7♦ 2♥: BB check, BTN check. Turn 4♠: BB check, BTN ставит 5 BB в банк 10 BB."],
              question: "Как называется ставка BTN на turn в этом сценарии?", answer: .choice(options: ["Delayed c-bet", "Probe bet BB", "Donk bet BB"], correct: 0),
              explanation: ["BTN был последним preflop aggressor.", "Он пропустил ставку на flop, а затем поставил на turn после check-through.", "Это соответствует определению delayed c-bet."],
              typicalError: "Называть delayed c-bet любую ставку на turn без проверки flop-линии.", term: "Delayed c-bet", definition: "Ставка последнего preflop aggressor на следующей улице после check-through предыдущей улицы.", example: "BB check → BTN check на флопе; BB check → BTN bet на тёрне.", method: "Сначала назовите preflop aggressor, затем восстановите действия на предшествующей улице.", assumptions: "Термин фиксирует историю линии; частота delayed c-bet и выбор карт требуют отдельной модели.", resultKind: .definitions,
              diagram: [.init("Flop", "BB check → BTN check"), .init("Turn", "BB check → BTN bet"), .init("Тег", "delayed c-bet")], cards: [Card(id: 50), Card(id: 31), Card(id: 13), Card(id: 2)], researchAnchor: "nlhe-complete-knowledge-map.md#t34"),
        .init(id: "E.foundation.t34.delayed-price", topicID: .t34, title: "Цена колла против delayed c-bet", purpose: .transfer,
              context: ["NLHE cash 6-max, BTN — preflop aggressor IP, BB OOP; flop прошёл check-through.", "Turn: pot 10 BB, BB check, BTN delayed c-bet 5 BB, BB рассматривает call 5 BB; effective stack 90 BB.", "Один банк, без рейка и будущих ставок."],
              question: "Введите порог equity BB для колла в процентах, округляя до 0,01.", answer: .number(value: try! CourseRangesMath.callThresholdPercent(call: 5, finalPot: 20), tolerance: 0.01),
              explanation: ["Итоговый банк после колла: 10 + 5 + 5 = 20 BB.", "Цена BB: 5 BB.", "5 / 20 = 25,00 %."],
              typicalError: "Считать порог как 5 / 15 и забыть собственный колл в итоговом банке.", term: "Pot odds", definition: "Отношение доплаты за колл к банку после этого колла.", example: "5 BB в итоговом банке 20 BB требуют 25,00 % в заданной модели.", method: "Соберите итоговый банк после своего колла и разделите цену колла на этот итог.", assumptions: "Единицы — BB; отсутствие рейка, будущей улицы и side pot; термин линии не изменяет арифметику; округление до 0,01 п.п.", resultKind: .exact,
              diagram: [.init("Turn pot", "10 BB"), .init("Bet / call", "5 BB / 5 BB"), .init("Порог", "5 / 20 = 25,00 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t34"),
        .init(id: "E.foundation.t34.probe-boundary", topicID: .t34, title: "Ставка OOP на turn", purpose: .boundary,
              context: ["NLHE cash 6-max, BTN открыл, BB колл; effective stack 100 BB.", "Flop K♣ 7♦ 2♥: BB check, BTN check. Turn 4♠: BB ставит 5 BB первым в банк 10 BB."],
              question: "Какой термин линии применим к ставке BB?", answer: .choice(options: ["Probe bet", "Delayed c-bet BTN", "C-bet BTN на flop"], correct: 0),
              explanation: ["IP игрок BTN имел возможность поставить на flop и сделал check.", "На следующей улице OOP игрок BB ставит первым.", "В учебном определении это probe bet."],
              typicalError: "Называть ставку BB delayed c-bet, игнорируя, кто был preflop aggressor.", term: "Probe bet", definition: "Ставка OOP после того, как IP соперник мог поставить на прошлой улице и сделал check.", example: "BB bet turn после BTN check flop.", method: "Проверьте последнюю улицу: кто имел право ставить и кто поставил первым на новой улице.", assumptions: "Определение фиксировано для курса; размер 5 BB и текстура доски не доказывают частоту или качество линии.", resultKind: .definitions,
              diagram: [.init("Flop", "BB check → BTN check"), .init("Turn", "BB bet 5 BB"), .init("Тег", "probe")], cards: [Card(id: 50), Card(id: 31), Card(id: 13), Card(id: 2)], researchAnchor: "nlhe-complete-knowledge-map.md#t34"),

        .init(id: "E.foundation.t34.cbet", topicID: .t34, title: "Продолженная ставка на флопе", purpose: .concept,
              context: ["NLHE cash 6-max, BTN open 2,5 BB, BB call, остальные фолд. Блайнды 0,5/1 BB, ante 0, рейк 0.", "На флопе K♣7♦2♥ в банке 5,5 BB, эффективный остаток 97,5 BB. BB check, BTN ставит 2,75 BB."],
              question: "Как называется ставка BTN в этой линии?", answer: .choice(options: ["C-bet префлоп-агрессора", "Donk BB", "Delayed c-bet на тёрне"], correct: 0),
              explanation: ["Последним агрессором префлопа был BTN.", "Он ставит на следующей улице, флопе, после чека BB.", "Это c-bet. Частота и качество ставки требуют отдельной модели диапазонов."],
              typicalError: "Определять c-bet только по маленькому размеру ставки.", term: "C-bet", definition: "Ставка префлоп-агрессора на флопе при заданной истории действий.", example: "BTN open, BB call; BB check, BTN bet flop.", method: "Отметьте префлоп-агрессора и проверьте, на какой улице он ставит.", assumptions: "Банк 2,5 + 2,5 + 0,5 = 5,5 BB. Учебный термин описывает линию; игровые диапазоны и оптимальная частота здесь не определяются.", resultKind: .definitions,
              diagram: [.init("Префлоп", "BTN open → BB call"), .init("Флоп", "BB check → BTN bet"), .init("Доля ставки", "2,75 / 5,5 = 1/2 банка")], cards: [Card(id: 50), Card(id: 31), Card(id: 13)], researchAnchor: "nlhe-complete-knowledge-map.md#t34"),

        // MARK: T35 — probe and donk with explicit initiative history
        .init(id: "E.foundation.t35.probe", topicID: .t35, title: "Probe после check-back", purpose: .concept,
              context: ["NLHE cash 6-max, BTN — последний агрессор префлопа, BB колл; на указанной улице осталось 100 BB эффективного стека.", "Flop A♣ 8♦ 3♠: BB check, BTN check. Turn 6♥: BB ставит 6 BB первым в банк 12 BB."],
              question: "Как классифицируется ставка BB на turn?", answer: .choice(options: ["Probe bet", "Donk bet", "C-bet BTN"], correct: 0),
              explanation: ["BTN был IP и на flop сделал check-back.", "BB остаётся OOP и ставит первым на следующей улице.", "История соответствует probe bet."],
              typicalError: "Считать любую ставку BB донком без проверки check-back IP игрока.", term: "Probe bet", definition: "Ставка OOP на новой улице после check-back IP соперника на предыдущей.", example: "BB check, BTN check flop; BB bet turn.", method: "Восстановите по улицам инициативу и check-back до присвоения термина.", assumptions: "Термин зависит от истории действий; стратегия ставки, карты и размеры требуют отдельной условной модели.", resultKind: .definitions,
              diagram: [.init("Flop", "BB check → BTN check"), .init("Turn", "BB bet 6 BB"), .init("Тег", "probe")], cards: [Card(id: 51), Card(id: 32), Card(id: 1), Card(id: 17)], researchAnchor: "nlhe-complete-knowledge-map.md#t35"),
        .init(id: "E.foundation.t35.donk-price", topicID: .t35, title: "Цена колла против donk", purpose: .transfer,
              context: ["NLHE cash 6-max, BTN открыл, BB колл; effective stack 100 BB.", "Flop: BB check, BTN c-bet 4 BB в 12 BB, BB call. Turn bank 20 BB; BB ставит 10 BB первым, BTN рассматривает call 10 BB.", "По определению курса это donk после c-bet агрессора на предыдущей улице; один банк, без рейка и будущих ставок."],
              question: "Введите порог equity BTN для колла в процентах, округляя до 0,01.", answer: .number(value: try! CourseRangesMath.callThresholdPercent(call: 10, finalPot: 40), tolerance: 0.01),
              explanation: ["К моменту решения в банке 20 + 10 = 30 BB.", "После колла итог: 40 BB.", "10 / 40 = 25,00 %."],
              typicalError: "Делить call 10 BB на 30 BB и получить цену до собственного колла.", term: "Donk bet", definition: "Ставка OOP в preflop aggressor после того, как агрессор поставил на предыдущей улице по заданной линии.", example: "BB call c-bet flop и первым ставит turn.", method: "Сначала восстановите агрессию на прошлой улице, затем отдельно посчитайте цену текущего колла.", assumptions: "Единицы — BB; линия и термин заданы курсом; pot odds точны в модели без рейка и будущих ставок; округление до 0,01 п.п.", resultKind: .exact,
              diagram: [.init("Flop", "BTN c-bet 4 → BB call"), .init("Turn", "pot 20; BB bet 10"), .init("Порог BTN", "10 / 40 = 25,00 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t35"),
        .init(id: "E.foundation.t35.term-boundary", topicID: .t35, title: "Граница термина donk", purpose: .boundary,
              context: ["NLHE cash 6-max, BTN открыл, BB колл; effective stack 100 BB.", "Flop: BB check, BTN check. Turn: BB ставит первым 6 BB в банк 12 BB.", "В курсе probe и donk различаются по тому, была ли ставка IP игрока на предыдущей улице."],
              question: "Почему эта ставка не получает тег donk в определении курса?", answer: .choice(options: ["BTN сделал check на flop, поэтому история соответствует probe", "BB всегда OOP", "Размер 6 BB меньше банка"], correct: 0),
              explanation: ["Классификатор сначала смотрит на check-back BTN.", "OOP и размер ставки сами по себе не определяют термин.", "После check-back ставка BB на новой улице — probe в фиксированной терминологии курса."],
              typicalError: "Сводить понятие donk к ставке игрока без позиции.", term: "История инициативы", definition: "Последовательность действий предыдущих улиц, необходимая для классификации текущей ставки.", example: "Один и тот же размер BB bet может быть probe или donk при разной flop-линии.", method: "Запишите действия по улицам перед названием ставки; используйте термин только после этой проверки.", assumptions: "Некоторые школы используют названия шире; курс использует явные определения из паспорта темы.", resultKind: .definitions,
              diagram: [.init("Flop", "BB check → BTN check"), .init("Turn", "BB bet"), .init("Причина", "check-back → probe")], researchAnchor: "nlhe-complete-knowledge-map.md#t35"),

        // MARK: T37 — exact river threshold and conditional postflop branches
        .init(id: "E.foundation.t37.river-value", topicID: .t37, title: "Value в заданной модели колла", purpose: .concept,
              context: ["NLHE cash 6-max: на ривере BTN против BB, банк 30 BB, остатки по 60 BB, рейк 0.", "BTN A♠Q♣; доска Q♦7♣4♥2♠9♦. Диапазон BB: Q♥Q♠ вес 1, J♣T♣ вес 3.", "Авторская политика: обе руки BB всегда коллируют ставку BTN 20 BB. Альтернатива — check и вскрытие. Других действий и банков нет."],
              question: "Каков EV ставки BTN от текущего решения, в BB? Округлите до 0,01.", answer: .number(value: try! CourseRangesMath.riverBetEV(equity: 0.75, finalPot: 70, bet: 20), tolerance: 0.01),
              explanation: ["QQ побеждает Hero, JT проигрывает. В заданном диапазоне доля побед Hero: 3 / (1 + 3) = 75 %.", "После bet и call банк: 30 + 20 + 20 = 70 BB. EV = 0,75 × 70 − 20 = 32,50 BB.", "EV check = 0,75 × 30 = 22,50 BB. Прибавка от ставки 10 BB следует из заданных худших коллов."],
              typicalError: "Назвать любую пару value-ставкой без списка худших коллов или забыть вычесть ставку Hero.", term: "Value bet", definition: "Ставка, извлекающая ценность из продолжений худших рук при заданной политике соперника.", example: "В условном списке JT коллирует и уступает паре дам Hero.", method: "Задайте руки и веса колла, сравните вскрытия и взвесьте выплаты относительно текущего решения.", assumptions: "Это авторская условная политика, включая колл JT. Один банк, ривер, ничьих нет. Значение зависит от этих рук, весов и размера ставки.", resultKind: .conditionalModel,
              diagram: [.init("Худшие / все коллы", "3 / 4"), .init("EV bet", "0,75 × 70 − 20 = 32,50 BB"), .init("EV check", "0,75 × 30 = 22,50 BB")], cards: [Card(id: 12), Card(id: 49), Card(id: 36), Card(id: 44), Card(id: 15), Card(id: 0), Card(id: 33)], researchAnchor: "nlhe-complete-knowledge-map.md#t37"),
        .init(id: "E.foundation.t37.semi-bluff", topicID: .t37, title: "Ветви semi-bluff", purpose: .transfer,
              context: ["NLHE cash 6-max, BTN против BB, flop A♠ 7♠ 2♦, pot 12 BB, effective stack 94 BB.", "BTN держит K♠ Q♠ и ставит 6 BB. Учебная модель: при call сохраняется equity draw и возможна следующая улица; fold-ветвь тоже существует.", "Частоты фолда и call range не заданы."],
              question: "Какое описание ставки BTN точнее?", answer: .choice(options: ["Semi-bluff: есть fold-ветвь и текущая equity draw при call", "Чистый river bluff с нулевой showdown equity", "Гарантированная value bet"], correct: 0),
              explanation: ["K♠Q♠ на двух пиках имеет draw и текущую equity при call.", "Fold соперника создаёт отдельную немедленную ветвь EV.", "Без call range и будущей политики value или частоту линии утверждать нельзя."],
              typicalError: "Применить river-порог 40 % как полную формулу semi-bluff на flop.", term: "Semi-bluff", definition: "Ставка с текущей equity при call и возможной fold equity против диапазона соперника.", example: "Флеш-draw может выиграть при фолде или улучшиться после call.", method: "Разделите EV на fold и call ветви; в call ветви задайте equity, runout и будущую политику.", assumptions: "Это условная ветвящаяся модель; карты и pot известны, а частоты реакции и будущие выплаты требуют явных входов.", resultKind: .conditionalModel,
              diagram: [.init("Fold BB", "немедленный банк"), .init("Call BB", "equity draw + future"), .init("Тег", "semi-bluff")], cards: [Card(id: 12), Card(id: 5), Card(id: 26), Card(id: 11), Card(id: 10)], researchAnchor: "nlhe-complete-knowledge-map.md#t37"),
        .init(id: "E.foundation.t37.value-boundary", topicID: .t37, title: "Граница value и protection", purpose: .boundary,
              context: ["NLHE cash 6-max, BTN против BB, turn K♣ 7♦ 2♥ 4♠, pot 20 BB, effective stack 80 BB.", "BTN держит K♦ Q♦ и рассматривает bet 12 BB.", "Диапазон BB после линии, его веса и частота call худших рук не заданы."],
              question: "Какой вход необходим, чтобы проверить value-условие ставки BTN?", answer: .choice(options: ["Какие худшие руки BB продолжают и с какими весами", "Только наличие пары королей у BTN", "Название защиты банка"], correct: 0),
              explanation: ["Value bet требует достаточной массы call от худших рук в заданной модели.", "Одна сильная карта Hero не задаёт реакцию диапазона BB.", "Protection описывает цель ограничить бесплатные карты, а EV требует ветви реакций и их веса."],
              typicalError: "Называть protection самостоятельным доказательством положительного EV без диапазона продолжения.", term: "Value bet", definition: "Ставка, получающая достаточную взвешенную массу call от худших рук в заданной модели.", example: "KQ может ставить на value только после задания худших call рук BB.", method: "Перечислите call, fold и raise ветви диапазона с весами, затем считайте выплаты каждой ветви.", assumptions: "Стратегический вывод является условной моделью; pot и стек задают масштаб BB, но не заменяют диапазон и политику.", resultKind: .conditionalModel,
              diagram: [.init("Hero", "K♦ Q♦"), .init("Нужны", "хуже call hands + weights"), .init("Проверка", "ветви EV")], cards: [Card(id: 50), Card(id: 31), Card(id: 13), Card(id: 2), Card(id: 37), Card(id: 36)], researchAnchor: "nlhe-complete-knowledge-map.md#t37")
    ]
}
