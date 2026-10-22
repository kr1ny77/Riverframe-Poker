import Foundation

/// Arithmetic for explicitly disclosed M11 teaching models. These functions do
/// not choose a range or a betting line; callers provide every strategic input.
public enum CourseDistributionMathError: Error, Equatable, Sendable {
    case invalidAmount
    case nonFiniteResult
}

public enum CourseDistributionMath {
    public static func weightedMass(_ combinations: Double, weight: Double) throws -> Double {
        guard combinations.isFinite, weight.isFinite, combinations >= 0, (0...1).contains(weight) else {
            throw CourseDistributionMathError.invalidAmount
        }
        let result = combinations * weight
        guard result.isFinite else { throw CourseDistributionMathError.nonFiniteResult }
        return result
    }

    /// Future-net EQR: future net EV divided by raw-equity share of the current pot.
    /// Sunk contributions and a current call price stay outside this numerator.
    /// Results over 100% are meaningful when the disclosed future model creates them.
    public static func equityRealizationPercent(futureNetEV: Double, pot: Double, rawEquity: Double) throws -> Double {
        guard futureNetEV.isFinite, pot.isFinite, rawEquity.isFinite, pot > 0, rawEquity > 0, rawEquity <= 1 else {
            throw CourseDistributionMathError.invalidAmount
        }
        let result = futureNetEV / (pot * rawEquity) * 100
        guard result.isFinite else { throw CourseDistributionMathError.nonFiniteResult }
        return result
    }

    public static func multiwayCallThresholdPercent(call: Double, accessibleFinalPot: Double) throws -> Double {
        guard call.isFinite, accessibleFinalPot.isFinite, call >= 0, accessibleFinalPot > 0, call <= accessibleFinalPot else {
            throw CourseDistributionMathError.invalidAmount
        }
        let result = call / accessibleFinalPot * 100
        guard result.isFinite else { throw CourseDistributionMathError.nonFiniteResult }
        return result
    }

    /// Exact expectation in a fully enumerated, mutually exclusive outcome list.
    public static func expectedSharePercent(outcomeProbabilities: [Double], shares: [Double]) throws -> Double {
        guard !outcomeProbabilities.isEmpty, outcomeProbabilities.count == shares.count,
              outcomeProbabilities.allSatisfy({ $0.isFinite && $0 >= 0 }),
              shares.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              abs(outcomeProbabilities.reduce(0, +) - 1) < 1e-12 else {
            throw CourseDistributionMathError.invalidAmount
        }
        let result = zip(outcomeProbabilities, shares).reduce(0) { $0 + $1.0 * $1.1 } * 100
        guard result.isFinite else { throw CourseDistributionMathError.nonFiniteResult }
        return result
    }
}

public extension FoundationLesson {
    /// M11 uses physical-card counting and deliberately artificial future-action
    /// distributions. Range implications remain conditional models.
    static let distributionExercises: [FoundationExercise] = [
        // MARK: T30
        .init(id: "E.foundation.t30.nut-mass", topicID: .t30, title: "Фактический nuts на K-high доске", purpose: .concept,
              context: ["NLHE cash 6-max, CO против BTN, effective stack 100 bb, рейк 0. Flop K♠ 7♦ 2♣; банк 6 bb.", "Учебный список A={AA, KK, AK}; каждая допустимая комбинация имеет вес 1.", "Nuts на этой доске — KK set: AA является overpair и проигрывает set соперника."],
              question: "Сколько комбинаций фактического nuts содержит A?", answer: .number(value: 3, tolerance: 0),
              explanation: ["Один K♠ уже лежит на доске.", "Остаются K♥, K♦ и K♣; из них образуются три пары KK.", "AA и AK имеют более слабые руки, поэтому в nuts не входят."],
              typicalError: "Включить AA в nuts только потому, что это сильная пара.", term: "Nut advantage", definition: "Сравнение взвешенной массы фактически сильнейших комбинаций на конкретной доске.", example: "На K♠ 7♦ 2♣ три оставшиеся комбинации KK образуют set.", method: "Сначала определите сильнейшую возможную руку на доске, затем примените removal к её классу.", assumptions: "Точный комбинаторный счёт: board K♠ 7♦ 2♣ и равные веса. Вывод о ставках потребует ranges, реакций, дерева и рейка.", resultKind: .exact,
              diagram: [.init("K♠ на доске", "1 король исключён"), .init("Оставшиеся K", "3"), .init("Nut-масса A", "3")], cards: [Card(id: 11), Card(id: 31), Card(id: 39)], researchAnchor: "nlhe-complete-knowledge-map.md#t30"),
        .init(id: "E.foundation.t30.weighted-tail", topicID: .t30, title: "Вес верхней части диапазона", purpose: .transfer,
              context: ["NLHE cash 6-max, CO против BTN, flop K♠ 7♦ 2♣, банк 6 bb, effective stack 100 bb, рейк 0.", "В искусственной модели A содержит 6 AA с весом 0,5 и 3 KK с весом 1. Верхний учебный класс задан как AA overpair или KK set.", "Частоты заданы условием и не описывают поле."],
              question: "Введите взвешенную массу заданного верхнего класса A с точностью до 0,01.", answer: .number(value: try! CourseDistributionMath.weightedMass(6, weight: 0.5) + CourseDistributionMath.weightedMass(3, weight: 1), tolerance: 0.01),
              explanation: ["AA: 6 × 0,5 = 3.", "KK: 3 × 1 = 3.", "Взвешенная nut-масса: 3 + 3 = 6."],
              typicalError: "Сложить физические 6 и 3, игнорируя заданный вес AA.", term: "Вес комбинации", definition: "Доля физической комбинации в явно заданном диапазоне.", example: "Шесть AA с весом 0,5 дают массу 3.", method: "Умножьте количество допустимых комбинаций на вес каждого класса до суммирования.", assumptions: "Условная модель с указанными весами; единица ответа — взвешенные комбинации. Веса и последствия для линии меняются с входами.", resultKind: .conditionalModel,
              diagram: [.init("AA", "6 × 0,5 = 3"), .init("KK", "3 × 1 = 3"), .init("Итого", "6")], cards: [Card(id: 11), Card(id: 31), Card(id: 39)], researchAnchor: "nlhe-complete-knowledge-map.md#t30"),
        .init(id: "E.foundation.t30.advantage-limit", topicID: .t30, title: "Граница преимущества диапазона", purpose: .boundary,
              context: ["NLHE cash 6-max, CO против BTN, flop K♠ 7♦ 2♣, банк 6 bb, effective stack 100 bb, рейк 0.", "Известна только масса одного выбранного верхнего класса A. Веса прочих рук, equity на runout и реакции на ставку не заданы."],
              question: "Какой вывод корректен?", answer: .choice(options: ["A обязан ставить любой размер", "A имеет больший заданный nut-класс; EV ставки требует остальных входов", "Средняя equity A уже известна"], correct: 1),
              explanation: ["Nut-масса описывает только выбранный верхний класс.", "Средняя equity требует полного распределения и runout.", "Размер и EV ставки требуют ветвей fold/call/raise, стеков и рейка."],
              typicalError: "Перенести факт о верхнем классе в универсальную рекомендацию ставки.", term: "Range advantage", definition: "Сравнение полного распределения equity двух заданных диапазонов.", example: "Nut advantage и средняя equity могут указывать в разные стороны.", method: "Разделяйте точный счёт комбинаций и условную модель реакции диапазона.", assumptions: "Пограничная задача: стратегическая таблица не приложена; задача не делает рекомендации.", resultKind: .definitions,
              diagram: [.init("Точно", "выбранная верхняя масса"), .init("Нужны для EV", "веса, runout, реакции, рейк")], cards: [Card(id: 11), Card(id: 31), Card(id: 39)], researchAnchor: "nlhe-complete-knowledge-map.md#t30"),
        .init(id: "E.foundation.t30.river-range-contrast", topicID: .t30, title: "Range и nuts на фиксированном river", purpose: .transfer,
              context: ["NLHE cash 6-max, CO против BTN, river K♠ 7♦ 2♣ 9♥ 3♣, банк 20 bb, effective stack 100 bb, рейк 0; дальнейших улиц нет.", "Искусственные равновзвешенные списки: A={K♥K♦, A♣A♦}; B={7♠7♥, A♠Q♣}. Каждая из четырёх парных комбинаций имеет вероятность 1/4 при независимом равном выборе класса.", "Фактический nuts на этом river — K♥K♦; он есть только в A."],
              question: "Какова средняя showdown equity A против B в процентах?", answer: .number(value: 75, tolerance: 0.01),
              explanation: ["K♥K♦ выигрывает у 7♠7♥ и A♠Q♣: две победы.", "A♣A♦ проигрывает set 7♠7♥ и выигрывает у A♠Q♣: одна победа и одно поражение.", "A выигрывает 3 из 4 совместных исходов: 75,00 %."],
              typicalError: "Назвать наличие одного nuts достаточным для 100 % equity всего диапазона.", term: "Range advantage", definition: "Сравнение средней equity полного заданного распределения, отдельно от наличия nuts.", example: "A имеет nuts в половине собственных комбинаций, а его средняя equity равна 75 %.", method: "Перечислите все совместные комбинации с их весами и сравните руки evaluator-ом.", assumptions: "Точный полный перебор четырёх равновероятных пар на фиксированном river; искусственные ranges, один банк, рейк и будущие решения отсутствуют.", resultKind: .exact,
              diagram: [.init("KK против B", "2 победы"), .init("AA против 77 / AQ", "0 / 1"), .init("A", "3 / 4 = 75 %")], cards: [Card(id: 11), Card(id: 31), Card(id: 39), Card(id: 20), Card(id: 40)], researchAnchor: "nlhe-complete-knowledge-map.md#t30"),

        // MARK: T31
        .init(id: "E.foundation.t31.future-net-eqr", topicID: .t31, title: "Future-net EQR", purpose: .concept,
              context: ["NLHE cash 6-max, BTN IP против BB, flop A♣ 7♦ 2♥, банк 100 bb, effective stack 80 bb, рейк 0.", "Raw equity 40 % и future-net EV 30 bb являются отдельными заданными скалярами искусственной модели; будущие платежи уже вычтены.", "Определение урока: EQR = future-net EV / (банк × raw equity). Sunk-вклад и цена текущего решения находятся вне числителя."],
              question: "Введите EQR в процентах с точностью до 0,01.", answer: .number(value: try! CourseDistributionMath.equityRealizationPercent(futureNetEV: 30, pot: 100, rawEquity: 0.4), tolerance: 0.01),
              explanation: ["Raw-equity share банка: 100 × 0,40 = 40 bb.", "Future-net EV модели: 30 bb.", "30 / 40 = 75,00 %."],
              typicalError: "Делить EV на банк и назвать 30 % реализацией equity.", term: "Equity realization", definition: "Отношение future-net EV к raw-equity share текущего банка в конкретной модели.", example: "30 bb из raw-share 40 bb дают EQR 75 %.", method: "Назовите EV-конвенцию, банк и raw equity; затем делите future-net EV на pot × equity.", assumptions: "Формула точна при данной future-net EV-конвенции. Raw equity и будущие действия являются входами модели; sunk-вклады и цена текущего колла учитываются отдельно.", resultKind: .conditionalModel,
              diagram: [.init("Raw share", "100 × 40 % = 40 bb"), .init("Future-net EV", "30 bb"), .init("EQR", "30 / 40 = 75 %")], cards: [Card(id: 51), Card(id: 31), Card(id: 13)], researchAnchor: "nlhe-complete-knowledge-map.md#t31"),
        .init(id: "E.foundation.t31.above-hundred", topicID: .t31, title: "EQR выше 100 %", purpose: .transfer,
              context: ["NLHE cash 6-max, BTN IP против BB, turn A♣ 7♦ 2♥ 4♠, банк 50 bb, effective stack 70 bb, рейк 0.", "Raw equity 25 % и future-net EV 15 bb — отдельные заданные скаляры искусственной модели; EV уже включает будущие платежи.", "Используется та же конвенция EQR = future-net EV / (банк × equity); sunk-вклад и текущая цена решения вне числителя."],
              question: "Введите EQR в процентах с точностью до 0,01.", answer: .number(value: try! CourseDistributionMath.equityRealizationPercent(futureNetEV: 15, pot: 50, rawEquity: 0.25), tolerance: 0.01),
              explanation: ["Raw-share: 50 × 0,25 = 12,5 bb.", "Future-модель даёт future-net EV 15 bb.", "15 / 12,5 = 120,00 %; это возможно для этой условной конвенции."],
              typicalError: "Ограничить EQR 100 %, хотя в модели есть дополнительные выигрышные ветви.", term: "EV-конвенция", definition: "Явное правило, какие выплаты и расходы входят в записанный EV.", example: "Future-net EV 15 bb при raw-share 12,5 bb даёт 120 %.", method: "Сохраните одну и ту же EV-конвенцию в числителе и объяснении; не смешивайте её с ценой нового колла.", assumptions: "Условная модель: 15 bb уже рассчитаны из её ветвей. Изменение fold-частот, рейка, позиции или дерева меняет EQR.", resultKind: .conditionalModel,
              diagram: [.init("Raw share", "50 × 25 % = 12,5 bb"), .init("Future-net EV", "15 bb"), .init("EQR", "120 %")], cards: [Card(id: 51), Card(id: 31), Card(id: 13), Card(id: 2)], researchAnchor: "nlhe-complete-knowledge-map.md#t31"),
        .init(id: "E.foundation.t31.eqr-limit", topicID: .t31, title: "Граница переноса EQR", purpose: .boundary,
              context: ["NLHE cash 6-max, BTN IP против BB. Один пример на A♣ 7♦ 2♥ дал EQR 75 % в указанной модели.", "Новая ситуация: BB против CO OOP на 9♠ 8♠ 7♦, другой банк, стек и рейк. Future-ветви и raw equity не заданы."],
              question: "Как применить прежние 75 %?", answer: .choice(options: ["Использовать как точный коэффициент в новой ситуации", "Построить новую модель с raw equity, EV-конвенцией, позицией, рейком и ветвями", "Заменить ими pot odds"], correct: 1),
              explanation: ["EQR относится к выбранным входам и EV-конвенции.", "Новая доска, позиция и расходы меняют будущие ветви.", "Pot odds — отдельная цена решения; EQR её не заменяет."],
              typicalError: "Переносить коэффициент реализации между досками и позициями без нового паспорта.", term: "Playability", definition: "Свойства руки и линии, влияющие на будущую реализацию в заданной модели.", example: "IP и OOP на разных текстурах задают разные future-ветви.", method: "Сначала пересоберите модель, затем сравнивайте EQR в одной конвенции.", assumptions: "Понятийная граница; стратегическая частота и размер ставки отсутствуют.", resultKind: .definitions,
              diagram: [.init("Старая модель", "IP, A72, 75 %"), .init("Новые входы", "OOP, 987, рейк, дерево")], cards: [Card(id: 7), Card(id: 6), Card(id: 31)], researchAnchor: "nlhe-complete-knowledge-map.md#t31"),

        // MARK: T33
        .init(id: "E.foundation.t33.bb-coverage", topicID: .t33, title: "Coverage BB на низкой доске", purpose: .concept,
              context: ["NLHE cash 6-max, CO против BB, flop 6♠ 5♣ 4♠, банк 6 bb, effective stack 100 bb, рейк 0.", "Учебный BB range={76s,65s,54s,33,22}, каждый допустимый combo имеет вес 1.", "Coverage здесь означает массу этих перечисленных классов после board removal."],
              question: "Сколько допустимых комбинаций содержит этот список BB после removal?", answer: .number(value: 19, tolerance: 0),
              explanation: ["76s: 3; 65s: 2; 54s: 2, поскольку карты доски исключают suited-комбинации.", "33 и 22 дают по 6.", "3 + 2 + 2 + 6 + 6 = 19."],
              typicalError: "Использовать число комбинаций до flop и получить 24.", term: "Board coverage", definition: "Взвешенная масса заданного диапазона, заметно соединяющаяся с конкретной доской.", example: "На 6♠5♣4♠ перечисленный список BB содержит 19 допустимых combo.", method: "Перечислите каждый класс, удалите карты доски и только затем суммируйте веса.", assumptions: "Точный комбинаторный счёт для искусственного списка и заданного определения coverage. Вывод о линии требует full ranges и реакций.", resultKind: .exact,
              diagram: [.init("76s / 65s / 54s", "3 / 2 / 2"), .init("33 / 22", "6 / 6"), .init("Coverage", "19")], cards: [Card(id: 4), Card(id: 42), Card(id: 2)], researchAnchor: "nlhe-complete-knowledge-map.md#t33"),
        .init(id: "E.foundation.t33.weighted-coverage", topicID: .t33, title: "Взвешенное покрытие", purpose: .transfer,
              context: ["NLHE cash 6-max, CO против BB, flop 6♠ 5♣ 4♠, банк 6 bb, effective stack 100 bb, рейк 0.", "После removal BB имеет 3 комбинации 76s с весом 0,5 и 6 комбинаций 33 с весом 1. Остальные классы исключены из этого вопроса.", "Веса — заданная учебная модель."],
              question: "Введите взвешенную массу двух классов с точностью до 0,01.", answer: .number(value: try! CourseDistributionMath.weightedMass(3, weight: 0.5) + CourseDistributionMath.weightedMass(6, weight: 1), tolerance: 0.01),
              explanation: ["76s: 3 × 0,5 = 1,5.", "33: 6 × 1 = 6.", "Итого 7,5 взвешенной комбинации."],
              typicalError: "Назвать 9 физическими комбинациями, потеряв вес 0,5.", term: "Взвешенное coverage", definition: "Coverage, где каждая допустимая комбинация имеет явно заданный вес.", example: "3 combo с весом 0,5 дают массу 1,5.", method: "Считайте removal, умножайте на вес и сохраняйте единицу «взвешенные комбинации».", assumptions: "Условная модель весов; board и стек фиксированы. Частоты и сайзинг поля отсюда не выводятся.", resultKind: .conditionalModel,
              diagram: [.init("76s", "3 × 0,5 = 1,5"), .init("33", "6 × 1 = 6"), .init("Итого", "7,5")], cards: [Card(id: 4), Card(id: 42), Card(id: 2)], researchAnchor: "nlhe-complete-knowledge-map.md#t33"),
        .init(id: "E.foundation.t33.coverage-limit", topicID: .t33, title: "Граница board coverage", purpose: .boundary,
              context: ["NLHE cash 6-max, CO против BB, flop 6♠ 5♣ 4♠, банк 6 bb, effective stack 100 bb, рейк 0.", "BB имеет больше заданного coverage, чем CO. Полные веса обоих ranges, equity по runout и реакции на ставку не заданы."],
              question: "Что следует из этого счёта?", answer: .choice(options: ["BB автоматически имеет больше средней equity", "BB имеет больше массы указанного coverage; средняя equity и EV требуют полного расчёта", "CO обязан check"], correct: 1),
              explanation: ["Coverage — выбранная часть распределения, а не полный подсчёт equity.", "Overpair и другие классы CO могут иметь значимую массу.", "EV действия требует платежей и реакций, а не одного тега доски."],
              typicalError: "Считать coverage доказательством готового сайзинга или обязательного check.", term: "Паспорт модели", definition: "Список формата, позиций, стеков, рейка, ranges, доски, дерева и метрики результата.", example: "Без полного range и runout coverage остаётся частичным счётом.", method: "Покажите, что именно посчитано, и перечислите отсутствующие ветви до вывода о стратегии.", assumptions: "Пограничный случай без проверенной таблицы стратегии.", resultKind: .definitions,
              diagram: [.init("Посчитано", "coverage"), .init("Не посчитано", "полная equity и EV")], cards: [Card(id: 4), Card(id: 42), Card(id: 2)], researchAnchor: "nlhe-complete-knowledge-map.md#t33"),

        // MARK: T40
        .init(id: "E.foundation.t40.multiway-definition", topicID: .t40, title: "Три активных игрока", purpose: .concept,
              context: ["NLHE cash 6-max, flop A♠ 7♦ 2♣. UTG, CO и BTN остаются активны; банк 18 bb, effective stacks по 90 bb, рейк 0.", "UTG ставит 9 bb, CO коллирует 9 bb, BTN рассматривает колл 9 bb. Все три игрока покрывают вклад; side pot отсутствует."],
              question: "Как называется банк в этот момент?", answer: .choice(options: ["Heads-up", "Multiway", "Side pot"], correct: 1),
              explanation: ["В раздаче активно минимум три игрока.", "Side pot появляется от непокрытых вкладов, а здесь все покрытия равны.", "Порядок действий и equity должны учитывать два диапазона соперников."],
              typicalError: "Называть любой банк после ставки side pot или считать equity только против одного игрока.", term: "Multiway pot", definition: "Банк с минимум тремя активными игроками.", example: "UTG, CO и BTN на flop образуют multiway pot.", method: "Зафиксируйте активных игроков, порядок, вклады и доступные каждому банки.", assumptions: "Точное определение; ставки и стеки в bb, рейк 0. Стратегические частоты не заданы.", resultKind: .definitions,
              diagram: [.init("UTG", "bet 9"), .init("CO", "call 9"), .init("BTN", "решение 9")], cards: [Card(id: 12), Card(id: 31), Card(id: 39)], researchAnchor: "nlhe-complete-knowledge-map.md#t40"),
        .init(id: "E.foundation.t40.accessible-price", topicID: .t40, title: "Цена колла в общем банке", purpose: .transfer,
              context: ["NLHE cash 6-max, flop A♠ 7♦ 2♣. UTG, CO и BTN активны; после preflop у каждого осталось по 9 bb, рейк 0.", "Flop pot 18 bb; UTG ставит all-in 9 bb; CO коллирует all-in 9 bb; BTN добавляет последние 9 bb. Side pot отсутствует.", "Итоговый доступный BTN банк после call: 45 bb."],
              question: "Введите all-in порог доли банка для BTN в процентах с точностью до 0,01.", answer: .number(value: try! CourseDistributionMath.multiwayCallThresholdPercent(call: 9, accessibleFinalPot: 45), tolerance: 0.01),
              explanation: ["BTN добавляет 9 bb.", "Знаменатель включает его колл: 18 + 9 + 9 + 9 = 45 bb.", "9 / 45 = 20,00 %."],
              typicalError: "Делить 9 на 36 и пропустить собственный колл в итоговом банке.", term: "Доступный банк", definition: "Главный и побочные банки, которые данный игрок может выиграть после своего действия.", example: "При равных стеках BTN участвует во всех 45 bb.", method: "Сначала определите покрытие вкладов, затем соберите только доступные игроку банки и его добавку.", assumptions: "Точный all-in расчёт в bb. Две equity-связанные руки соперников и будущие улицы в порог не входят; они влияют на практический EV.", resultKind: .exact,
              diagram: [.init("До BTN", "18 + 9 + 9 = 36 bb"), .init("Колл BTN", "9 bb"), .init("Доступный банк", "45 bb"), .init("Порог", "9 / 45 = 20 %")], cards: [Card(id: 12), Card(id: 31), Card(id: 39)], researchAnchor: "nlhe-complete-knowledge-map.md#t40"),
        .init(id: "E.foundation.t40.joint-outcomes", topicID: .t40, title: "Совместные исходы и side pot", purpose: .boundary,
              context: ["NLHE cash 6-max, river A♠ 7♦ 2♣ 4♥ 9♠. Hero вложил 60 bb, Short вложил 20 bb all-in, Deep вложил 60 bb; рейк 0.", "Main pot 60 bb доступен всем; side pot 80 bb доступен только Hero и Deep. Полный исход определяется общими картами и всеми руками, события победы против Short и Deep могут зависеть друг от друга. Независимость условием не задана.", "Вероятности совместных исходов и ranges не заданы."],
              question: "Какой способ расчёта нужен для EV Hero?", answer: .choice(options: ["Перемножить две heads-up equity как независимые", "Перечислить совместные исходы и отдельно учесть eligibility main/side pot", "Использовать только main pot 60 bb"], correct: 1),
              explanation: ["Один runout одновременно определяет результаты против обоих соперников.", "В выигрыш side pot Hero может попасть только против Deep.", "Нужны совместные исходы или точный перебор объединённых диапазонов; heads-up произведение не описывает эту раздачу."],
              typicalError: "Перемножить heads-up equity, предполагая независимость общих карт и исходов.", term: "Eligibility side pot", definition: "Право игрока выиграть только те банки, для которых его вклад покрыт.", example: "Hero участвует в main 60 bb и side 80 bb; Short участвует только в main.", method: "Постройте банки по покрытым вкладам, затем считайте совместные outcomes с выплатой каждому eligible игроку.", assumptions: "Пограничная задача. Общие карты создают корреляцию; без ranges и совместного перечисления точную equity и EV назвать нельзя.", resultKind: .definitions,
              diagram: [.init("Main", "60 bb: Hero / Short / Deep"), .init("Side", "80 bb: Hero / Deep"), .init("Исход", "совместный, не независимый")], cards: [Card(id: 12), Card(id: 31), Card(id: 13), Card(id: 15), Card(id: 7)], researchAnchor: "nlhe-complete-knowledge-map.md#t40")
    ]
}
