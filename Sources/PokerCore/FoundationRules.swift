import Foundation

public enum FoundationRulesMathError: Error, Equatable, Sendable {
    case invalidAmount
    case nonPositivePot
    case invalidBetSequence
    case insufficientContributors
    case nonFiniteResult
}

/// Typed arithmetic for fixed educational inputs. Text in lessons never becomes executable math.
public enum FoundationRulesMath {
    public static func effectiveStack(heroRemaining: Double, opponentRemaining: Double) throws -> Double {
        guard heroRemaining.isFinite, opponentRemaining.isFinite,
              heroRemaining >= 0, opponentRemaining >= 0 else {
            throw FoundationRulesMathError.invalidAmount
        }
        let result = min(heroRemaining, opponentRemaining)
        guard result.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
        return result
    }

    public static func spr(effectiveRemaining: Double, pot: Double) throws -> Double {
        guard effectiveRemaining.isFinite, effectiveRemaining >= 0 else {
            throw FoundationRulesMathError.invalidAmount
        }
        guard pot.isFinite, pot > 0 else {
            throw FoundationRulesMathError.nonPositivePot
        }
        let result = effectiveRemaining / pot
        guard result.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
        return result
    }

    public static func potAfterBetAndCall(pot: Double, bet: Double) throws -> Double {
        guard pot.isFinite, bet.isFinite, pot >= 0, bet >= 0 else {
            throw FoundationRulesMathError.invalidAmount
        }
        let result = pot + 2 * bet
        guard result.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
        return result
    }

    public static func minimumRaiseTo(currentBet: Double, lastFullRaise: Double) throws -> Double {
        guard currentBet.isFinite, lastFullRaise.isFinite,
              currentBet >= 0, lastFullRaise > 0 else {
            throw FoundationRulesMathError.invalidAmount
        }
        let result = currentBet + lastFullRaise
        guard result.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
        return result
    }

    public static func actionReopens(previousBet: Double, currentBet: Double, lastFullRaise: Double) throws -> Bool {
        guard previousBet.isFinite, currentBet.isFinite, lastFullRaise.isFinite,
              previousBet >= 0, currentBet >= previousBet, lastFullRaise > 0 else {
            throw FoundationRulesMathError.invalidBetSequence
        }
        let increase = currentBet - previousBet
        guard increase.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
        return increase >= lastFullRaise
    }

    /// The most a short stack can put in to answer an existing wager.
    public static func callContribution(currentBet: Double, alreadyContributed: Double, remainingStack: Double) throws -> Double {
        guard currentBet.isFinite, alreadyContributed.isFinite, remainingStack.isFinite,
              currentBet >= 0, alreadyContributed >= 0, alreadyContributed <= currentBet,
              remainingStack >= 0 else {
            throw FoundationRulesMathError.invalidAmount
        }
        let result = min(currentBet - alreadyContributed, remainingStack)
        guard result.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
        return result
    }

    /// Returns the unmatched part of the largest total contribution.
    public static func uncalledReturn(contributions: [Double]) throws -> Double {
        guard contributions.count >= 2 else { throw FoundationRulesMathError.insufficientContributors }
        guard contributions.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw FoundationRulesMathError.invalidAmount
        }
        let sorted = contributions.sorted(by: >)
        let result = sorted[0] - sorted[1]
        guard result.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
        return result
    }

    /// A layer between two contribution levels; folded chips remain in the layer.
    public static func potLayer(lower: Double, upper: Double, contributions: [Double]) throws -> Double {
        guard lower.isFinite, upper.isFinite, lower >= 0, upper >= lower,
              contributions.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw FoundationRulesMathError.invalidAmount
        }
        var result = 0.0
        for contribution in contributions {
            let layerContribution = max(0, min(contribution, upper) - lower)
            guard layerContribution.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
            result += layerContribution
            guard result.isFinite else { throw FoundationRulesMathError.nonFiniteResult }
        }
        return result
    }

    public static func oddChipShares(pot: Int, winnerCount: Int) throws -> (base: Int, oddChips: Int) {
        guard pot >= 0, winnerCount > 0 else { throw FoundationRulesMathError.invalidAmount }
        return (pot / winnerCount, pot % winnerCount)
    }
}

public extension FoundationLesson {
    static let rulesExercises: [FoundationExercise] = [
        .init(
            id: "E.foundation.T03.spr", topicID: .t03, title: "SPR: банк и доступный остаток", purpose: .concept,
            context: ["Cash 6-max, блайнды 1/2.", "На флопе в банке 50. У Hero и Villain осталось по 200."],
            question: "Какой SPR в начале флопа?", answer: .number(value: try! FoundationRulesMath.spr(effectiveRemaining: 200, pot: 50), tolerance: 0.001),
            explanation: ["Эффективный остаток равен меньшему стеку: 200.", "SPR = 200 / 50 = 4."],
            typicalError: "Использовать стартовый стек вместо остатка на этой улице.", term: "SPR", definition: "Отношение эффективного остатка к банку в начале улицы.", example: "Остаток 90 и банк 30 дают SPR 3.", method: "Возьмите меньший остаток двух игроков и разделите на текущий банк.", assumptions: "Точный расчёт для заданных остатков и банка; SPR сам не выбирает линию.",
            diagram: [.init("Банк", "50"), .init("Эффективный остаток", "200"), .init("SPR", "4")], researchAnchor: "nlhe-complete-knowledge-map.md#t03"),
        .init(
            id: "E.foundation.T03.effective", topicID: .t03, title: "Эффективный стек против меньшего остатка", purpose: .transfer,
            context: ["На флопе банк 35.", "У Hero осталось 120, у Villain — 70."],
            question: "Какой SPR для этой пары игроков?", answer: .number(value: try! FoundationRulesMath.spr(effectiveRemaining: try! FoundationRulesMath.effectiveStack(heroRemaining: 120, opponentRemaining: 70), pot: 35), tolerance: 0.001),
            explanation: ["Оба игрока могут вложить вместе только до меньшего остатка 70.", "SPR = 70 / 35 = 2."],
            typicalError: "Делить 120 на банк, хотя Villain не может покрыть эти 50 фишек.", term: "Эффективный стек", definition: "Меньший доступный остаток в паре игроков.", example: "120 против 70 создаёт эффективный стек 70.", method: "Сначала найдите меньший остаток, затем считайте SPR.", assumptions: "Точный расчёт для heads-up части банка; multiway требует отдельного учёта участников.",
            diagram: [.init("Hero", "120"), .init("Villain", "70"), .init("Банк", "35"), .init("SPR", "2")], researchAnchor: "nlhe-complete-knowledge-map.md#t03"),
        .init(
            id: "E.foundation.T03.bba", topicID: .t03, title: "Кто вносит BB ante", purpose: .boundary,
            context: ["Учебный турнирный сценарий 6-max.", "Объявлен BB ante размером 1 BB; BB также платит свой блайнд."],
            question: "Кто вносит ante в этой раздаче?", answer: .choice(options: ["Каждый из шести игроков", "Только игрок на BB", "Только игрок на BTN"], correct: 1),
            explanation: ["BB ante вносит игрок на большом блайнде.", "Формат ante задают до подсчёта стартового банка."],
            typicalError: "Сложить шесть ante, как в формате ante от каждого игрока.", term: "BB ante", definition: "Турнирный ante, который вносит большой блайнд.", example: "В 6-max при BB ante 1 BB ante равен одной BB, а не шести.", method: "Назовите формат ante, затем складывайте обязательные ставки.", assumptions: "Учебная турнирная модель; cash-стол и домашние правила задаются отдельно.", resultKind: .definitions,
            diagram: [.init("SB", "0,5 BB"), .init("BB", "1 BB + 1 BB ante"), .init("Остальные", "0 ante")], researchAnchor: "nlhe-complete-knowledge-map.md#t03"),
        .init(
            id: "E.foundation.T03.cash-start-pot", topicID: .t03, title: "Стартовый банк cash-раздачи", purpose: .transfer,
            context: ["Cash 6-max, блайнды 1/2.", "Ante не объявлены. До действия все игроки имеют полный стек."],
            question: "Каков стартовый банк до действий игроков?", answer: .number(value: 3, tolerance: 0.001),
            explanation: ["В банк уже внесены малый блайнд 1 и большой блайнд 2.", "1 + 2 = 3."],
            typicalError: "Добавить BB ante, хотя для этой cash-раздачи он не задан.", term: "Стартовый банк", definition: "Сумма обязательных ставок, внесённых до добровольных действий.", example: "При 1/2 без ante стартовый банк равен 3.", method: "Сначала прочитайте формат: cash без объявленных antes или турнирный BB ante.", assumptions: "Учебный cash-сценарий без рейка; ante добавляется только когда он явно задан.",
            diagram: [.init("SB", "1"), .init("BB", "2"), .init("Ante", "0"), .init("Стартовый банк", "3")], researchAnchor: "nlhe-complete-knowledge-map.md#t03"),
        .init(
            id: "E.foundation.T03.turn-spr", topicID: .t03, title: "SPR после ставки и колла", purpose: .transfer,
            context: ["На флопе банк 30 и эффективный остаток 90.", "Hero ставит 15, Villain коллирует 15."],
            question: "Какой SPR в начале тёрна?", answer: .number(value: try! FoundationRulesMath.spr(effectiveRemaining: 75, pot: try! FoundationRulesMath.potAfterBetAndCall(pot: 30, bet: 15)), tolerance: 0.001),
            explanation: ["Банк становится 30 + 15 + 15 = 60.", "У обоих остаётся 75.", "SPR тёрна = 75 / 60 = 1,25."],
            typicalError: "Оставить банк 30 или вычесть ставку только у одного игрока.", term: "Точка расчёта", definition: "SPR считают в начале конкретной улицы.", example: "После ставки и колла меняются и банк, и остатки.", method: "Сначала обновите банк и остатки, затем делите.", assumptions: "Точная арифметика; рейк и другие игроки отсутствуют.",
            diagram: [.init("Флоп: банк", "30"), .init("Ставка + колл", "+30"), .init("Тёрн: банк / остаток", "60 / 75"), .init("SPR", "1,25")], researchAnchor: "nlhe-complete-knowledge-map.md#t03"),
        .init(
            id: "E.foundation.T03.zero-pot", topicID: .t03, title: "Предел формулы SPR", purpose: .boundary,
            context: ["До обязательных ставок и antes стартовый банк ещё не задан.", "Доступный остаток игрока равен 100."],
            question: "Можно ли получить численный SPR без размера банка?", answer: .choice(options: ["Да, SPR равен 100", "Да, SPR равен 0", "Нет, нужен положительный банк"], correct: 2),
            explanation: ["В знаменателе SPR стоит банк.", "При нулевом или неизвестном банке численный SPR не определён."],
            typicalError: "Назвать остаток стеком-to-pot ratio без банка в знаменателе.", term: "Ограничение формулы", definition: "Деление на ноль не даёт численного отношения.", example: "100 / 0 не является SPR.", method: "Зафиксируйте положительный банк до вычисления отношения.", assumptions: "Проверка определения; обязательные ставки ещё не сложены.", resultKind: .definitions,
            diagram: [.init("Остаток", "100"), .init("Банк", "не задан"), .init("SPR", "нужен банк")], researchAnchor: "nlhe-complete-knowledge-map.md#t03"),

        .init(
            id: "E.foundation.T04.min-raise", topicID: .t04, title: "Минимальное повышение", purpose: .concept,
            context: ["Турнирный учебный сценарий TDA.", "Текущая ставка 20, последнее полное повышение составило 20."],
            question: "До какой суммы минимум можно повысить?", answer: .number(value: try! FoundationRulesMath.minimumRaiseTo(currentBet: 20, lastFullRaise: 20), tolerance: 0.001),
            explanation: ["Минимальная добавка равна последнему полному повышению: 20.", "20 + 20 = raise-to 40."],
            typicalError: "Ответить 20, хотя вопрос просит итоговую ставку raise-to.", term: "Raise-to", definition: "Итоговая сумма ставки игрока после повышения.", example: "С 20 до 40 означает повышение на 20.", method: "Прибавьте размер последнего полного повышения к текущей ставке.", assumptions: "Правило TDA для учебного турнира; cash-room может установить house rules.",
            diagram: [.init("Текущая ставка", "20"), .init("Полное повышение", "+20"), .init("Минимум raise-to", "40")], researchAnchor: "nlhe-complete-knowledge-map.md#t04"),
        .init(
            id: "E.foundation.T04.next-min-raise", topicID: .t04, title: "Новый минимум после большого открытия", purpose: .transfer,
            context: ["Турнирный учебный сценарий TDA.", "Ставка выросла с 20 до 60; последнее полное повышение равно 40."],
            question: "До какой суммы минимум следующее полное повышение?", answer: .number(value: try! FoundationRulesMath.minimumRaiseTo(currentBet: 60, lastFullRaise: 40), tolerance: 0.001),
            explanation: ["Размер последнего полного повышения — 60 − 20 = 40.", "Следующее raise-to: 60 + 40 = 100."],
            typicalError: "Добавить исходные 20 вместо последнего полного повышения 40.", term: "Последнее полное повышение", definition: "Полная добавка, по которой определяется следующий минимум.", example: "20 → 60 задаёт размер 40.", method: "Вычтите прежнюю ставку из новой, затем прибавьте результат к current bet.", assumptions: "Точная арифметика в сценарии TDA; история действий задана полностью.",
            diagram: [.init("Было", "20"), .init("Стало", "60"), .init("Размер повышения", "40"), .init("Следующий минимум", "100")], researchAnchor: "nlhe-complete-knowledge-map.md#t04"),
        .init(
            id: "E.foundation.T04.short-all-in", topicID: .t04, title: "Короткий all-in и повторное открытие", purpose: .boundary,
            context: ["Турнирный учебный сценарий TDA.", "A открыл до 30: последнее полное повышение равно 20.", "B коллировал 30. C поставил all-in 45."],
            question: "Может ли A сразу сделать re-raise сверх колла 15?", answer: .choice(options: ["Да, любой all-in открывает re-raise", "Нет, короткая добавка 15 меньше полного повышения 20", "Да, но только до 45"], correct: 1),
            explanation: ["C добавил 15 к ставке 30.", "15 меньше последнего полного повышения 20, поэтому A может fold или call 15."],
            typicalError: "Считать любой all-in полноценным повышением.", term: "Неполный all-in", definition: "All-in с добавкой меньше требуемого полного повышения.", example: "30 → 45 даёт добавку 15 при полном повышении 20.", method: "Сравните добавку с последним полным повышением и учтите, действовал ли игрок ранее.", assumptions: "TDA Rule 49 для учебного турнира; cash house rules проверяются отдельно.", resultKind: .definitions,
            diagram: [.init("A открывает", "30"), .init("C all-in", "45"), .init("Добавка", "15 < 20"), .init("A", "fold / call 15")], researchAnchor: "nlhe-complete-knowledge-map.md#t04"),
        .init(
            id: "E.foundation.T04.cumulative", topicID: .t04, title: "Сумма коротких повышений", purpose: .transfer,
            context: ["Турнирный учебный сценарий TDA.", "A открыл до 30, B коллировал 30.", "C all-in 45, затем D all-in 50. Последнее полное повышение равно 20."],
            question: "До какой суммы минимум может повысить A, если действие снова открыто?", answer: .number(value: try! FoundationRulesMath.minimumRaiseTo(currentBet: 50, lastFullRaise: 20), tolerance: 0.001),
            explanation: ["От 30 до 50 накопилась добавка 20.", "Она равна полному повышению и открывает A действие.", "Минимум raise-to = 50 + 20 = 70."],
            typicalError: "Считать только последнюю добавку 5 и игнорировать накопление 15 + 5.", term: "Накопленное повышение", definition: "Сумма коротких добавок после действия игрока.", example: "30 → 45 → 50 даёт 20.", method: "Сравните текущую ставку с той, на которую игрок уже реагировал.", assumptions: "TDA Rule 49; все действия и размеры повышений указаны.",
            diagram: [.init("Ставка после A", "30"), .init("Короткие all-in", "45 → 50"), .init("Накопление", "20"), .init("Минимум A raise-to", "70")], researchAnchor: "nlhe-complete-knowledge-map.md#t04"),
        .init(
            id: "E.foundation.T04.short-call", topicID: .t04, title: "Колл коротким стеком", purpose: .boundary,
            context: ["Турнирный учебный сценарий.", "Текущая ставка 50. Hero уже вложил 20 и имеет за спиной 17."],
            question: "Сколько Hero может вложить, чтобы ответить на ставку?", answer: .number(value: try! FoundationRulesMath.callContribution(currentBet: 50, alreadyContributed: 20, remainingStack: 17), tolerance: 0.001),
            explanation: ["Полная цена колла была бы 50 − 20 = 30.", "У Hero есть 17, поэтому он может выставиться на 17."],
            typicalError: "Требовать 30 фишек у игрока, у которого их 17.", term: "Короткий колл all-in", definition: "Вклад всех оставшихся фишек, когда полного колла не хватает.", example: "Цена 30 и стек 17 дают all-in 17.", method: "Вычтите уже внесённое и сравните цену с остатком.", assumptions: "Легальность конкретного стола проверяет движок; задача считает доступный вклад.",
            diagram: [.init("Текущая ставка", "50"), .init("Уже внесено", "20"), .init("Цена полного колла", "30"), .init("Остаток / вклад", "17 / 17")], researchAnchor: "nlhe-complete-knowledge-map.md#t04"),
        .init(
            id: "E.foundation.T04.check", topicID: .t04, title: "Чек при нулевой цене", purpose: .concept,
            context: ["На новой улице соперник ещё не ставил.", "Текущая ставка равна 0; у Hero осталось 17."],
            question: "Какое действие доступно Hero без вложения фишек?", answer: .choice(options: ["Чек", "Колл 17", "Обязательный фолд"], correct: 0),
            explanation: ["Цена продолжения равна нулю.", "Hero может чекнуть; короткий стек не делает колл обязательным."],
            typicalError: "Называть чек коллом или считать любой короткий стек all-in действием.", term: "Чек", definition: "Передача действия при нулевой цене продолжения.", example: "До первой ставки на улице игрок может чекнуть.", method: "Сначала определите текущую цену: при нуле доступен чек.", assumptions: "Учебный NLHE-сценарий; очередность хода уже корректна.", resultKind: .definitions,
            diagram: [.init("Текущая ставка", "0"), .init("Цена действия", "0"), .init("Доступное действие", "чек")], researchAnchor: "nlhe-complete-knowledge-map.md#t04"),

        .init(
            id: "E.foundation.T05.main-pot", topicID: .t05, title: "Главный и побочный банк", purpose: .concept,
            context: ["A выставился на 50. B и C выставились на 100.", "Все трое дошли до вскрытия."],
            question: "Каков размер главного банка?", answer: .number(value: try! FoundationRulesMath.potLayer(lower: 0, upper: 50, contributions: [50, 100, 100]), tolerance: 0.001),
            explanation: ["В главный слой каждый внёс первые 50.", "50 × 3 = 150."],
            typicalError: "Сложить все 250 фишек и назвать результат главным банком.", term: "Главный банк", definition: "Первый слой вкладов, за который могут бороться все оплатившие его игроки.", example: "50/100/100 создают main pot 150.", method: "Возьмите общий нижний уровень вкладов и умножьте на число участников слоя.", assumptions: "Точная бухгалтерия; все три игрока имеют право на этот слой.",
            diagram: [.init("A", "50"), .init("B", "100"), .init("C", "100"), .init("Главный банк", "150")], researchAnchor: "nlhe-complete-knowledge-map.md#t05"),
        .init(
            id: "E.foundation.T05.layers", topicID: .t05, title: "Слои банка и возврат", purpose: .transfer,
            context: ["Вклады A/B/C/D: 30 / 70 / 70 / 100.", "A, B и C дошли до вскрытия; D тоже внёс фишки до all-in."],
            question: "Каков размер побочного банка между уровнями 30 и 70?", answer: .number(value: try! FoundationRulesMath.potLayer(lower: 30, upper: 70, contributions: [30, 70, 70, 100]), tolerance: 0.001),
            explanation: ["В слой 30–70 входят B, C и D: по 40.", "40 × 3 = 120.", "Верхние 30 D не покрыты и возвращаются отдельно."],
            typicalError: "Убрать вклад D из слоя 30–70 или оставить его непокрытые 30 в банке.", term: "Побочный банк", definition: "Слой вкладов выше лимита одного из all-in игроков.", example: "30/70/70/100 создаёт side pot 120 между 30 и 70.", method: "Считайте каждый уровень вкладов отдельно; потом выделите непокрытый верх.", assumptions: "Точная бухгалтерия; D участвует во вскрытии, а его верхние 30 не покрыты и возвращаются.",
            diagram: [.init("0–30: четыре вклада", "120"), .init("30–70: B, C, D", "120"), .init("70–100: D", "возврат 30")], researchAnchor: "nlhe-complete-knowledge-map.md#t05"),
        .init(
            id: "E.foundation.T05.folded-eligibility", topicID: .t05, title: "Фолд и право на банк", purpose: .boundary,
            context: ["A вложил 50 и сфолдил. B вложил 100, C вложил 100.", "Созданы main pot 150 и side pot 100."],
            question: "Кто имеет право выиграть side pot 100?", answer: .choice(options: ["A, B и C", "B и C", "Только A"], correct: 1),
            explanation: ["Фишки A остаются в главном банке.", "После фолда A не имеет права на вскрытие и на побочный банк.", "B и C оплатили уровень side pot."],
            typicalError: "Дать игроку после фолда право на банк из-за его прежнего вклада.", term: "Eligible", definition: "Игрок, оплативший слой и сохранивший право участвовать во вскрытии.", example: "Сфолдировавшийся вклад остаётся в банке, право на выигрыш исчезает.", method: "Для каждого слоя разделите размер банка и список игроков с правом на него.", assumptions: "Точная механика банка; победитель вскрытия в условии отдельно не задан.", resultKind: .definitions,
            diagram: [.init("Main 150", "B, C eligible; A chips remain"), .init("Side 100", "B, C eligible"), .init("A", "folded")], researchAnchor: "nlhe-complete-knowledge-map.md#t05"),
        .init(
            id: "E.foundation.T05.refund", topicID: .t05, title: "Возврат непокрытой ставки", purpose: .transfer,
            context: ["Вклады A/B/C/D: 30 / 70 / 70 / 100.", "После всех действий никто не может покрыть верхние фишки D."],
            question: "Сколько фишек возвращается D как непокрытая часть?", answer: .number(value: try! FoundationRulesMath.uncalledReturn(contributions: [30, 70, 70, 100]), tolerance: 0.001),
            explanation: ["Второй по величине вклад равен 70.", "100 − 70 = 30 не покрыты и возвращаются D."],
            typicalError: "Оставить непокрытую часть в side pot без соперника.", term: "Непокрытая ставка", definition: "Часть верхнего вклада, которую никто не может оплатить.", example: "100 против следующего уровня 70 возвращает 30.", method: "Сравните наибольший вклад со вторым по величине уровнем.", assumptions: "Точная бухгалтерия; все вклады относятся к одной завершённой ветви банка.",
            diagram: [.init("Наибольший вклад D", "100"), .init("Следующий уровень", "70"), .init("Возврат D", "30")], researchAnchor: "nlhe-complete-knowledge-map.md#t05"),
        .init(
            id: "E.foundation.T05.odd-chip", topicID: .t05, title: "Нечётная фишка при дележе", purpose: .boundary,
            context: ["Учебный турнирный сценарий TDA.", "Банк 101 делят два равных победителя. Один из них расположен первым слева от BTN."],
            question: "Сколько фишек получает первый победитель слева от BTN?", answer: .number(value: 51, tolerance: 0.001),
            explanation: ["Каждый получает базовую долю 101 / 2 = 50 и остаток 1.", "По TDA Rule 21 odd chip идёт первому победителю слева от BTN.", "Этот игрок получает 51."],
            typicalError: "Разделить 101 пополам с дробной фишкой или отдать остаток произвольному игроку.", term: "Odd chip", definition: "Нечётная фишка, оставшаяся после равного дележа банка.", example: "101 на двоих даёт 50 каждому и одну odd chip.", method: "Разделите банк нацело, затем примените правило раздачи остатка выбранного регламента.", assumptions: "TDA Rule 21 для учебного турнира; cash и домашние правила стола могут задавать иной порядок.",
            diagram: [.init("Банк", "101"), .init("Базовая доля", "50 + 50"), .init("Odd chip", "1 → первый слева от BTN"), .init("Итог", "51 / 50")], researchAnchor: "nlhe-complete-knowledge-map.md#t05"),
    ]
}
