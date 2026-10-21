import Foundation

/// Independent constants and small exact calculations used by the foundation catalogue.
/// They document the values checked against `nlhe-complete-knowledge-map.md`.
public enum FoundationStudyMath {
    public static let deckSize = 52
    public static let unseenAfterFiveKnown = 47
    public static let dirtyOutsClean = 7
    public static let dirtyOutsDirty = 2
    public static let dirtyOutsTotalRiver = 44

    public static func percent(_ numerator: Int, _ denominator: Int) -> Double {
        100 * Double(numerator) / Double(denominator)
    }

    /// C(3, 1) × C(44, 1) / C(47, 2), with no replacement.
    public static var exactlyOneAceByRiverPercent: Double {
        percent(3 * 44, 47 * 46 / 2)
    }

    public static var dirtyOutEquityPercent: Double {
        percent(dirtyOutsClean, dirtyOutsTotalRiver)
    }

    public static func equityPercent(wins: Int, ties: Int, total: Int) -> Double {
        100 * (Double(wins) + Double(ties) / 2) / Double(total)
    }

    public static func weightedEquityPercent(firstEquity: Double, firstWeight: Int, secondEquity: Double, secondWeight: Int) -> Double {
        (firstEquity * Double(firstWeight) + secondEquity * Double(secondWeight)) / Double(firstWeight + secondWeight)
    }
}

public extension FoundationLesson {
    /// Exercises fill gaps around the legacy sets. Each topic has a concept,
    /// changed-input and boundary task; grading remains typed Swift data.
    static let remainingExercises: [FoundationExercise] = [
        // MARK: T06 — combinations and sampling without replacement
        .init(id: "E.foundation.t06.classes", topicID: .t06, title: "Классы стартовых рук", purpose: .concept,
              context: ["Колода содержит 52 уникальные карты.", "Рассматриваются только классы стартовых рук: пары, suited и offsuit."],
              question: "Сколько классов стартовых рук в матрице 13×13?", answer: .number(value: 169, tolerance: 0),
              explanation: ["Матрица содержит 13 строк и 13 столбцов.", "13 × 13 = 169 классов.", "Класс объединяет несколько физических комбинаций."],
              typicalError: "Считать 1 326 физических комбинаций ответом на вопрос о классах.", term: "Класс руки", definition: "Обозначение рангов и мастности, например AKs; оно объединяет физические комбинации.", example: "AKs — четыре физические комбинации, но один класс.", method: "Сначала назовите, требуется класс или конкретные карты. Для классов используйте матрицу 13×13.", assumptions: "Точная комбинаторика полной колоды без известных карт.", resultKind: .exact,
              diagram: [.init("Матрица рангов", "13 × 13"), .init("Классы", "169")], researchAnchor: "nlhe-complete-knowledge-map.md#t06"),
        .init(id: "E.foundation.t06.one-ace", topicID: .t06, title: "Ровно один туз к риверу", purpose: .transfer,
              context: ["На флопе известны Hero и три общие карты: всего пять карт.", "Среди 47 неизвестных карт осталось три туза.", "Требуется ровно один туз на тёрне и ривере."],
              question: "Введите точную вероятность в процентах с точностью до 0,01.", answer: .number(value: FoundationStudyMath.exactlyOneAceByRiverPercent, tolerance: 0.01),
              explanation: ["Выбираем один из трёх тузов и одну из 44 остальных карт.", "Подходящих пар: 3 × 44 = 132; всех пар: C(47, 2) = 1 081.", "132 / 1 081 = 12,21 %."],
              typicalError: "Сложить 3/47 и 3/46: это считает случаи двух тузов и не отделяет событие «ровно один».", term: "Выбор без возвращения", definition: "Открытая карта остаётся известной и не возвращается в колоду перед следующим открытием.", example: "После промаха на тёрне знаменатель на ривере равен 46.", method: "Опишите событие, затем считайте сочетания подходящих и всех пар.", assumptions: "Неизвестные карты равновероятны; burn-карты и карты соперника остаются неизвестными.", resultKind: .exact,
              diagram: [.init("Подходящие пары", "3 × 44 = 132"), .init("Все пары", "C(47, 2) = 1 081")], researchAnchor: "nlhe-complete-knowledge-map.md#t06"),
        .init(id: "E.foundation.t06.no-return", topicID: .t06, title: "Знаменатель после промаха", purpose: .boundary,
              context: ["На флопе осталось три туза среди 47 неизвестных карт.", "Тёрн оказался не тузом."],
              question: "Какая дробь описывает шанс туза именно на ривере?", answer: .choice(options: ["3 / 47", "3 / 46", "4 / 46"], correct: 1),
              explanation: ["Один неподходящий тёрн уже открыт.", "Три туза остаются среди 46 неизвестных карт.", "Верная дробь: 3 / 46."],
              typicalError: "Сохранить знаменатель 47 и тем самым вернуть открытую карту в колоду.", term: "Условная вероятность", definition: "Вероятность следующего события после того, как предыдущий исход уже известен.", example: "Промах на тёрне меняет размер неизвестной части колоды.", method: "После каждого известного открытия обновляйте числитель и знаменатель.", assumptions: "Тёрн точно известен как не-туз; иных карт из колоды дополнительно не раскрывали.", resultKind: .definitions,
              diagram: [.init("До тёрна", "3 / 47"), .init("После промаха", "3 / 46")], researchAnchor: "nlhe-complete-knowledge-map.md#t06"),

        // MARK: T07 — exact outs and dirty outs
        .init(id: "E.foundation.t07.clean-outs", topicID: .t07, title: "Чистые ауты против сета", purpose: .concept,
              context: ["Turn: Hero A♠ J♠; Villain K♦ K♣; board K♠ 7♦ 2♠ 4♥.", "Из 44 river-карт девять пиков закрывают флеш. Пики K♠ уже на доске, A♠ и J♠ у Hero."],
              question: "Сколько пиковых river-карт являются чистыми победными аутами Hero?", answer: .number(value: Double(FoundationStudyMath.dirtyOutsClean), tolerance: 0),
              explanation: ["Всего возможны девять пиковых river-карт.", "4♠ и 7♠ дают Villain фулл-хаус и остаются проигрышными для Hero.", "Чистыми остаются 9 − 2 = 7 карт."],
              typicalError: "Назвать все девять пиков чистыми без сравнения готовых пятёрок соперника.", term: "Dirty out", definition: "Карта улучшает вид руки, но часть таких продолжений проигрывает против заданной руки или диапазона.", example: "7♠ даёт Hero флеш, а Villain — фулл-хаус короли и семёрки.", method: "Для каждого кандидата добавьте карту к обеим рукам и сравните лучшие пятёрки.", assumptions: "Одна известная рука соперника, один общий банк, ривер завершает торговлю.", resultKind: .exact,
              diagram: [.init("Пиковые кандидаты", "9"), .init("Dirty", "4♠, 7♠"), .init("Clean", "7")], cards: [Card(id: 12), Card(id: 9), Card(id: 37), Card(id: 50), Card(id: 11), Card(id: 31), Card(id: 0), Card(id: 15)], researchAnchor: "nlhe-complete-knowledge-map.md#t07"),
        .init(id: "E.foundation.t07.river-equity", topicID: .t07, title: "Equity после dirty outs", purpose: .transfer,
              context: ["Тот же turn: A♠ J♠ против K♦ K♣ на K♠ 7♦ 2♠ 4♥.", "Точный перебор river: 7 побед, 0 ничьих, 37 поражений из 44 карт."],
              question: "Введите точную equity Hero в процентах с точностью до 0,01.", answer: .number(value: FoundationStudyMath.dirtyOutEquityPercent, tolerance: 0.01),
              explanation: ["Equity при одном банке равна (wins + ties / 2) / outcomes.", "(7 + 0 / 2) / 44 = 7 / 44.", "Итог: 15,91 %."],
              typicalError: "Взять 9/44 и включить dirty outs как победы.", term: "Equity", definition: "Средняя доля итогового общего банка при заданных исходах.", example: "Семь побед из 44 без ничьих дают 7/44 банка в среднем.", method: "Сначала классифицируйте W/T/L, затем учитывайте ничью как половину банка.", assumptions: "Ривер открывается всегда; рейка, будущих ставок и побочных банков нет.", resultKind: .exact,
              diagram: [.init("W / T / L", "7 / 0 / 37"), .init("Equity", "7 / 44 = 15,91 %")], cards: [Card(id: 12), Card(id: 9), Card(id: 37), Card(id: 50), Card(id: 11), Card(id: 31), Card(id: 0), Card(id: 15)], researchAnchor: "nlhe-complete-knowledge-map.md#t07"),
        .init(id: "E.foundation.t07.rule-four", topicID: .t07, title: "Предел правила 2 и 4", purpose: .boundary,
              context: ["Hero имеет draw на флопе.", "Нужно получить точное число для решения в учебной задаче."],
              question: "Какой способ даёт точную вероятность в этой задаче?", answer: .choice(options: ["Умножить ауты на 4", "Перебрать или посчитать сочетания неизвестных карт", "Всегда считать каждый out чистым"], correct: 1),
              explanation: ["Правило 2 и 4 является быстрой оценкой.", "Точный ответ получают сочетаниями или полным перебором разрешённых runout.", "Статус аутов требует отдельной проверки против руки или диапазона."],
              typicalError: "Выдать эвристику за точный расчёт и не проверить dirty outs.", term: "Эвристика", definition: "Упрощённое приближение, удобное для оценки, без гарантии точности в каждом входе.", example: "Правило 2 и 4 удобно за столом, а каталог показывает точные значения отдельной меткой.", method: "Используйте эвристику для быстрой оценки; для проверяемого ответа перечисляйте исходы.", assumptions: "Карты соперника и его диапазон заданы, когда требуется оценить чистоту аута.", resultKind: .definitions,
              diagram: [.init("Оценка", "правило 2 и 4"), .init("Точный ответ", "сочетания или перебор")], researchAnchor: "nlhe-complete-knowledge-map.md#t07"),

        // MARK: T08 — known-hand equity and valid inputs
        .init(id: "E.foundation.t08.tie-share", topicID: .t08, title: "Ничья в equity", purpose: .concept,
              context: ["Дана учебная сводка условной модели: 44 равновероятных исхода вскрытия.", "Hero имеет 10 побед, 4 ничьи и 30 поражений."],
              question: "Введите equity Hero в процентах с точностью до 0,01.", answer: .number(value: FoundationStudyMath.equityPercent(wins: 10, ties: 4, total: 44), tolerance: 0.01),
              explanation: ["Каждая ничья даёт половину общего банка.", "(10 + 4 / 2) / 44 = 12 / 44.", "Equity равна 27,27 %."],
              typicalError: "Использовать только 10/44 и потерять половины банка из ничьих.", term: "Ничья", definition: "Исход, в котором лучшие пятёрки равны и общий банк делится по правилам раздачи.", example: "Четыре ничьи добавляют к equity две полные доли банка.", method: "Подставьте wins + ties / 2 в числитель и число всех runout в знаменатель.", assumptions: "Два игрока и один общий банк. W/T/L заданы как входы арифметической модели; конкретные руки здесь не восстанавливаются.", resultKind: .conditionalModel,
              diagram: [.init("W / T / L", "10 / 4 / 30"), .init("Доля", "(10 + 4/2) / 44")], researchAnchor: "nlhe-complete-knowledge-map.md#t08"),
        .init(id: "E.foundation.t08.complete-turn", topicID: .t08, title: "Все river-исходы", purpose: .transfer,
              context: ["Hero и Villain имеют по две известные карты; board содержит четыре известные карты turn.", "Все восемь известных карт уникальны."],
              question: "Сколько равновероятных river-карт перебирает точный heads-up расчёт?", answer: .number(value: 44, tolerance: 0),
              explanation: ["Из 52 карт известны две Hero, две Villain и четыре board-карты.", "52 − 8 = 44 неизвестные карты.", "Каждая из них образует один river-runout."],
              typicalError: "Взять 46 и не исключить известные две карты соперника.", term: "Runout", definition: "Полная последовательность оставшихся общих карт, определяющая вскрытие.", example: "На turn один river-кандидат образует один runout.", method: "Сначала перечислите все раскрытые карты, затем вычтите их из 52.", assumptions: "Карты обеих рук известны; burn-карты не раскрыты и остаются среди неизвестных.", resultKind: .exact,
              diagram: [.init("Известно", "2 + 2 + 4 = 8"), .init("River", "52 − 8 = 44")], researchAnchor: "nlhe-complete-knowledge-map.md#t08"),
        .init(id: "E.foundation.t08.duplicate-card", topicID: .t08, title: "Валидность входа equity", purpose: .boundary,
              context: ["В задаче указаны Hero A♠ K♥, Villain A♠ Q♦ и board из пяти иных карт.", "Требуется подготовить вход для точного перебора."],
              question: "Как оценить такой вход?", answer: .choice(options: ["Валиден: A♠ может быть у двух игроков", "Невалиден: физическая карта A♠ повторена", "Валиден только при делении банка"], correct: 1),
              explanation: ["В одной колоде каждая физическая карта существует один раз.", "A♠ нельзя назначить одновременно Hero и Villain.", "Перебор начинается после проверки уникальности всех известных карт."],
              typicalError: "Сравнить ранги и пропустить повтор конкретной карты.", term: "Валидный вход", definition: "Набор карт и условий, который может существовать в одной раздаче.", example: "A♠ у Hero исключает A♠ из диапазона соперника.", method: "Проверьте количество карт и уникальность ID до расчёта W/T/L.", assumptions: "Одна стандартная колода из 52 уникальных карт.", resultKind: .definitions,
              diagram: [.init("Hero", "A♠ K♥"), .init("Villain", "A♠ Q♦ → повтор")], researchAnchor: "nlhe-complete-knowledge-map.md#t08"),

        // MARK: T09 — weighted ranges
        .init(id: "E.foundation.t09.weights", topicID: .t09, title: "Вес как относительная масса", purpose: .concept,
              context: ["Учебный диапазон содержит две допустимые физические комбинации: первая вес 2, вторая вес 3.", "Вес задаёт относительную массу после заданной линии."],
              question: "Какова нормированная вероятность первой комбинации?", answer: .number(value: 40, tolerance: 0.01),
              explanation: ["Сумма весов равна 2 + 3 = 5.", "Масса первой комбинации: 2 / 5.", "2 / 5 = 40 %."],
              typicalError: "Принять вес 2 за вероятность 2 % или не нормировать веса.", term: "Вес диапазона", definition: "Относительная вероятность конкретной допустимой комбинации в заданной модели.", example: "Веса 2 и 3 превращаются в вероятности 40 % и 60 %.", method: "Сложите все веса и разделите вес каждой ветви на эту сумму.", assumptions: "Две альтернативные легальные руки; веса положительны и относятся к одному моменту раздачи.", resultKind: .conditionalModel,
              diagram: [.init("Веса", "2 : 3"), .init("Нормировка", "2 / 5 = 40 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t09"),
        .init(id: "E.foundation.t09.weighted-equity", topicID: .t09, title: "Взвешенная equity", purpose: .transfer,
              context: ["Hero A♠ K♥; тёрн T♠ J♥ Q♦ 2♣; один общий банк, ставки завершены, рейк 0.", "Диапазон соперника: A♦ K♣ с весом 3 и 9♠ 9♥ с весом 2.", "У каждой альтернативы 44 равновероятных ривера: против AK все ничьи, против 99 все победы Hero."],
              question: "Введите equity Hero по этому диапазону в процентах с точностью до 0,01.", answer: .number(value: FoundationStudyMath.weightedEquityPercent(firstEquity: 50, firstWeight: 3, secondEquity: 100, secondWeight: 2), tolerance: 0.01),
              explanation: ["Против AK доля банка 50 %, против 99 — 100 %.", "Сумма весов: 3 + 2 = 5. Взвешенная сумма: 50 × 3 + 100 × 2 = 350.", "350 / 5 = 70 %."],
              typicalError: "Взять простое среднее 75 % и проигнорировать веса.", term: "Взвешенное среднее", definition: "Среднее, в котором каждая ветвь влияет пропорционально своей массе.", example: "Ветка с весом 3 учитывается в полтора раза сильнее ветки с весом 2.", method: "Умножьте equity каждой ветви на её вес, сложите и разделите на сумму весов.", assumptions: "Руки альтернативны: карты другой ветви остаются в колоде. Перебор внутри каждой ветви точен, веса заданы учебной моделью.", resultKind: .conditionalModel,
              diagram: [.init("Против AK", "50 % × 3"), .init("Против 99", "100 % × 2"), .init("Итог", "350 / 5 = 70 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t09"),
        .init(id: "E.foundation.t09.blocked-range", topicID: .t09, title: "Диапазон с занятой картой", purpose: .boundary,
              context: ["Hero держит A♠ J♠.", "В диапазон соперника добавлена комбинация A♠ K♦ с ненулевым весом."],
              question: "Что нужно сделать с комбинацией A♠ K♦ перед расчётом диапазона?", answer: .choice(options: ["Оставить: вес исправит повтор", "Исключить: A♠ уже у Hero", "Удвоить вес остальных рук"], correct: 1),
              explanation: ["Физическая карта A♠ уже известна у Hero.", "Комбинация соперника с этой картой невозможна.", "После исключения нормируйте веса оставшихся легальных комбинаций."],
              typicalError: "Сохранить невозможную ветвь и получить формально точное среднее от неверного диапазона.", term: "Removal effect", definition: "Известная карта уменьшает или исключает комбинации диапазона, содержащие эту карту.", example: "A♠ у Hero исключает A♠K♦ у Villain.", method: "Сначала удалите пересечения с Hero и board, затем проверяйте веса и вычисляйте среднее.", assumptions: "Диапазон описывает одну руку соперника в каждой альтернативной ветви.", resultKind: .conditionalModel,
              diagram: [.init("Hero", "A♠ J♠"), .init("Ветка", "A♠ K♦ → исключить")], researchAnchor: "nlhe-complete-knowledge-map.md#t09"),

        // MARK: T21 — starting hands and domination
        .init(id: "E.foundation.t21.dominated-ace", topicID: .t21, title: "Доминированный туз", purpose: .concept,
              context: ["Hero: A♠ J♠. Рассматривается showdown на доске A♦ 8♣ 4♥ 2♣ 7♦.", "Соперник может иметь A♥ K♥ или A♥ Q♥."],
              question: "Почему A♠ J♠ проигрывает обеим указанным рукам на этой доске?", answer: .choice(options: ["У соперника старший kicker при одинаковой паре тузов", "Масти всегда старше", "Hero использует шесть карт"], correct: 0),
              explanation: ["Обе стороны имеют пару тузов.", "Kicker K или Q старше J Hero.", "Масти не участвуют в сравнении этих пятёрок."],
              typicalError: "Оценить только наличие туза и пропустить kicker.", term: "Доминирование", definition: "Ситуация, в которой общий старший ранг часто оставляет руку с худшим kicker позади.", example: "AJo на A-high board часто уступает AK и AQ.", method: "Сравните лучшие пять карт при одинаковой категории и назовите первый различающийся kicker.", assumptions: "Конкретные руки и board заданы; вывод о диапазоне и линии требует дополнительных входов.", resultKind: .definitions,
              diagram: [.init("Hero", "A J"), .init("Villain", "A K или A Q"), .init("Разница", "kicker")], researchAnchor: "nlhe-complete-knowledge-map.md#t21"),
        .init(id: "E.foundation.t21.remaining-combos", topicID: .t21, title: "Комбинации после blocker", purpose: .transfer,
              context: ["До карт Hero диапазон {AKs, AKo, AQo} содержит 4 + 12 + 12 = 28 комбинаций.", "Hero держит A♠ J♠."],
              question: "Сколько комбинаций этого диапазона остаётся после удаления рук с A♠?", answer: .number(value: 21, tolerance: 0),
              explanation: ["A♠ удаляет одну suited AK-комбинацию, три offsuit AKo и три offsuit AQo.", "Удалено 1 + 3 + 3 = 7 комбинаций.", "28 − 7 = 21 комбинация."],
              typicalError: "Удалить все комбинации с тузом или не удалить ни одной.", term: "Blocker", definition: "Известная карта, которая уменьшает число доступных физических комбинаций с этой картой.", example: "A♠ у Hero исключает A♠K♦ из диапазона Villain.", method: "Раскройте класс в физические комбинации и исключите только комбинации с известной картой.", assumptions: "Диапазон задан до карт Hero; другие карты board отсутствуют из условия.", resultKind: .exact,
              diagram: [.init("До blocker", "28 combo"), .init("Удалено A♠", "7 combo"), .init("Остаётся", "21 combo")], researchAnchor: "nlhe-complete-knowledge-map.md#t21"),
        .init(id: "E.foundation.t21.playability-limit", topicID: .t21, title: "Предел ярлыка «доминирована»", purpose: .boundary,
              context: ["Hero рассматривает J♠ T♠ против широкого диапазона.", "Позиция, стек, рейк, действия и board пока не заданы."],
              question: "Какой вывод корректен до появления этих входов?", answer: .choice(options: ["Рука автоматически слабая из-за отсутствия туза", "Нужны контекст и диапазон; мастность и связность могут менять играбельность", "Любая suited рука обязана играться"], correct: 1),
              explanation: ["Доминирование описывает конкретные отношения рук, например AJo против AK/AQ.", "JTs может иметь другие свойства: связность и suitedness.", "Решение требует позиции, стека, рейка, действий и предполагаемого диапазона."],
              typicalError: "Превратить один пример доминирования в универсальное правило выбора рук.", term: "Играбельность", definition: "Свойства руки в заданном контексте: как она реализует equity и какие продолжения создаёт.", example: "J♠T♠ и AJo имеют разные риски и возможности на разных board.", method: "Отделяйте точный счёт комбинаций от условного решения по стартовой руке.", assumptions: "Стратегическая оценка остаётся учебной моделью с явным паспортом условий.", resultKind: .conditionalModel,
              diagram: [.init("Точный факт", "свойства карт"), .init("Нужные входы", "позиция, стек, рейк, диапазон")], researchAnchor: "nlhe-complete-knowledge-map.md#t21"),

        // MARK: T22 — RFI charts as conditional models
        .init(id: "E.foundation.t22.rfi-definition", topicID: .t22, title: "Условие RFI", purpose: .concept,
              context: ["6-max cash, Hero на CO.", "UTG и HJ сфолдили; до Hero добровольных коллов и рейзов нет."],
              question: "Как называется рейз Hero до первого добровольного входа в банк?", answer: .choice(options: ["Cold call", "RFI / open-raise", "Squeeze"], correct: 1),
              explanation: ["До Hero все игроки сфолдили.", "Hero становится первым добровольным участником банка рейзом.", "Это raise first in, или open-raise."],
              typicalError: "Назвать любой префлоп-рейз squeeze без open и caller перед ним.", term: "RFI", definition: "Raise first in: рейз игрока, когда до него все сфолдили.", example: "CO открывает после fold UTG и HJ.", method: "Прочитайте действия перед игроком: последовательность одних fold создаёт RFI.", assumptions: "Блайнды считаются вынужденными вложениями и не отменяют статус RFI.", resultKind: .definitions,
              diagram: [.init("До CO", "UTG fold → HJ fold"), .init("Действие CO", "open 2,5 BB")], researchAnchor: "nlhe-complete-knowledge-map.md#t22"),
        .init(id: "E.foundation.t22.players-behind", topicID: .t22, title: "Игроки позади CO", purpose: .transfer,
              context: ["6-max, CO открывает первым до 2,5 BB.", "BTN, SB и BB ещё активны."],
              question: "Сколько игроков сохраняют право действовать после рейза CO?", answer: .number(value: 3, tolerance: 0),
              explanation: ["После CO в 6-max идут BTN, SB и BB.", "Каждый из них может fold, call или raise по условиям раздачи.", "Итого три игрока позади CO."],
              typicalError: "Посчитать только блайнды и пропустить BTN.", term: "Игроки позади", definition: "Активные игроки, которые ещё не завершили действие в текущем раунде.", example: "После CO открывает BTN, затем SB и BB.", method: "Идите по префлоп-порядку от текущей позиции до BB и исключайте уже сфолдивших.", assumptions: "6-max; все три позиции активны; размер рейза не меняет число игроков с правом действия.", resultKind: .exact,
              diagram: [.init("CO", "рейз"), .init("Позади", "BTN → SB → BB = 3")], researchAnchor: "nlhe-complete-knowledge-map.md#t22"),
        .init(id: "E.foundation.t22.chart-co-read", topicID: .t22, title: "Чтение учебной таблицы CO", purpose: .transfer,
              context: ["Авторская учебная модель для чтения меток: 6-max cash, effective stack 100 BB, ante 0, рейк 0, open 2,5 BB.", "Hero на CO; UTG и HJ сфолдили. Таблица показывает метки только для этого паспорта и этой позиции.", "Hero держит K♠ Q♠."],
              question: "Какую метку таблица даёт KQs на CO в этом точно заданном сценарии?", answer: .choice(options: ["Открыть", "Сфолдить", "Для KQs метки нет"], correct: 0),
              explanation: ["В строке KQs учебной таблицы стоит метка «Открыть».", "Паспорт задачи задаёт позицию CO, 6-max cash, 100 BB, ante 0, рейк 0 и open 2,5 BB.", "Метка помогает прочитать условную модель; она не доказывает оптимальность вне этих входов."],
              typicalError: "Перенести метку CO в MTT, другую позицию, иной стек или другой рейк без нового паспорта.", term: "Учебная таблица", definition: "Небольшой набор меток для чтения решения внутри явно заданной модели.", example: "В этой авторской модели KQs на CO имеет метку «Открыть».", method: "Сначала сверяйте паспорт и позицию, затем находите класс руки и его метку в таблице.", assumptions: "Авторская учебная модель, созданная для чтения меток; она не является проверенной таблицей, solver-выводом или гарантией выигрыша.", resultKind: .conditionalModel,
              diagram: [.init("Позиция", "CO после fold UTG и HJ"), .init("Паспорт", "6-max cash · 100 BB · ante 0 · рейк 0 · open 2,5 BB")],
              chart: [.init("AA", "Открыть"), .init("KK", "Открыть"), .init("QQ", "Открыть"), .init("AKs", "Открыть"), .init("AQo", "Открыть"), .init("KQs", "Открыть")],
              cards: [Card(id: 11), Card(id: 10)], researchAnchor: "nlhe-complete-knowledge-map.md#t22"),
        .init(id: "E.foundation.t22.chart-passport", topicID: .t22, title: "Паспорт учебного чарта", purpose: .boundary,
              context: ["Показан учебный чарт для 6-max cash, 100 BB effective, без анте, с указанным рейком и размером open.", "Hero играет MTT с 18 BB и ante."],
              question: "Как применить этот чарт к ситуации Hero?", answer: .choice(options: ["Использовать без изменений", "Сначала выбрать модель с совпадающими форматом, стеком, ante и условиями", "Расширить все диапазоны на одну позицию"], correct: 1),
              explanation: ["Чарт — результат конкретной модели, а не закон выбора рук.", "Cash 100 BB без ante и MTT 18 BB с ante имеют разные входы.", "Сначала нужен паспорт подходящей учебной модели."],
              typicalError: "Перенести набор рук между форматами только по совпадению названия позиции.", term: "Паспорт чарта", definition: "Набор условий модели: формат, позиции, стеки, ante, рейк, сайзинг и допущения.", example: "6-max cash 100 BB и MTT 18 BB с ante имеют разные паспорта.", method: "Сверьте каждый параметр с подписью чарта до использования как учебной подсказки.", assumptions: "Чарт в задаче — условная учебная модель; оптимальность и универсальная прибыльность не заявляются.", resultKind: .conditionalModel,
              diagram: [.init("Чарт", "6-max cash · 100 BB · без ante"), .init("Hero", "MTT · 18 BB · ante")], researchAnchor: "nlhe-complete-knowledge-map.md#t22"),

        // MARK: T28 — format and action order
        .init(id: "E.foundation.t28.hu-order", topicID: .t28, title: "Порядок в heads-up", purpose: .concept,
              context: ["Heads-up: BTN одновременно ставит SB, второй игрок ставит BB.", "Оба игрока остаются в раздаче после флопа."],
              question: "Кто действует первым префлоп и кто действует последним postflop?", answer: .choice(options: ["BB в обоих раундах", "BTN/SB префлоп и BTN/SB postflop последним", "BTN/SB всегда первым"], correct: 1),
              explanation: ["В heads-up BTN является SB.", "Он действует первым префлоп, затем последним после флопа.", "BB закрывает префлоп и действует первым postflop."],
              typicalError: "Перенести порядок 6-max на heads-up без учёта двойной роли BTN/SB.", term: "Heads-up", definition: "Формат раздачи с двумя игроками.", example: "BTN/SB открывает префлоп, BB отвечает; на флопе BB действует первым.", method: "Сначала зафиксируйте формат, затем назначьте SB/BB и порядок каждой улицы.", assumptions: "Оба игрока активны; порядок относится к стандартным правилам NLHE.", resultKind: .definitions,
              diagram: [.init("Префлоп", "BTN/SB → BB"), .init("Postflop", "BB → BTN/SB")], researchAnchor: "nlhe-complete-knowledge-map.md#t28"),
        .init(id: "E.foundation.t28.co-behind", topicID: .t28, title: "CO в 6-max и full ring", purpose: .transfer,
              context: ["В 6-max CO готовится к RFI; BTN, SB и BB активны.", "В full ring CO также готовится к RFI; BTN, SB и BB активны."],
              question: "Сколько игроков непосредственно позади CO в каждой из этих двух ситуаций?", answer: .choice(options: ["3 в 6-max и 3 в full ring", "2 в 6-max и 6 в full ring", "5 в 6-max и 8 в full ring"], correct: 0),
              explanation: ["После CO в обоих форматах сидят BTN, SB и BB.", "Поэтому непосредственно позади CO три игрока в каждом случае.", "Full ring отличается числом позиций и фолдов до CO, а не этим хвостом порядка."],
              typicalError: "Подменить число игроков позади общим числом игроков за столом.", term: "Формат стола", definition: "Число мест и связанный с ним порядок позиций в раздаче.", example: "CO имеет BTN, SB и BB позади и в 6-max, и в full ring.", method: "Считайте позиции после конкретного места, затем отдельно учитывайте путь до него.", assumptions: "Все перечисленные позиции активны; задача описывает только порядок, без диапазонной рекомендации.", resultKind: .exact,
              diagram: [.init("6-max после CO", "BTN → SB → BB"), .init("Full ring после CO", "BTN → SB → BB")], researchAnchor: "nlhe-complete-knowledge-map.md#t28"),
        .init(id: "E.foundation.t28.table-limit", topicID: .t28, title: "Предел переноса RFI между форматами", purpose: .boundary,
              context: ["Учебный чарт описывает 9-max UTG RFI: после Hero действуют UTG+1, UTG+2, LJ, HJ, CO, BTN, SB и BB — восемь игроков.", "Hero рассматривает первую позицию 6-max, где после него действуют HJ, CO, BTN, SB и BB — пять игроков.", "Стек, ante, рейк и размер open для 6-max отдельно не заданы."],
              question: "Как использовать 9-max UTG чарт для первой позиции 6-max?", answer: .choice(options: ["Перенести без изменений: обе позиции называются ранними", "Сначала задать 6-max паспорт модели; число игроков позади и условия отличаются", "Сделать диапазон уже на три класса рук"], correct: 1),
              explanation: ["В 9-max UTG после Hero восемь игроков, в первой позиции 6-max — пять.", "Это меняет дерево решений ещё до учёта стеков, ante, рейка и сайзинга.", "Перенос без модели не обоснован; нужен паспорт учебного чарта для 6-max."],
              typicalError: "Сопоставить позиции только по ярлыку «ранняя» и пропустить число игроков с правом действия позади.", term: "Перенос модели", definition: "Использование вывода одной учебной модели в ситуации с другими входами.", example: "9-max UTG и первая позиция 6-max различаются числом игроков позади: 8 и 5.", method: "Сверьте формат, позиции, стеки, ante, рейк и размер open до переноса диапазона.", assumptions: "Чарт является условной учебной моделью; набор рук и его частоты требуют собственного паспорта.", resultKind: .conditionalModel,
              diagram: [.init("9-max UTG", "8 игроков позади"), .init("6-max первая позиция", "5 игроков позади"), .init("Вывод", "нужен новый паспорт")], researchAnchor: "nlhe-complete-knowledge-map.md#t28"),
    ]
}
