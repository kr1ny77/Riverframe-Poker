import Foundation

public enum CourseMonteCarloError: Error, Equatable, Sendable {
    case invalidSampleCount
    case invalidReportCounts
}

/// A reproducible estimate of heads-up showdown share. The report stores the
/// sampled W/T/L counts, so its uncertainty can be recomputed without replaying
/// the random runouts.
public struct CourseMonteCarloReport: Sendable, Equatable {
    public static let maximumSamples = 100_000

    public let seed: UInt64
    public let wins: Int
    public let ties: Int
    public let losses: Int

    public init(seed: UInt64, wins: Int, ties: Int, losses: Int) throws {
        guard wins >= 0, ties >= 0, losses >= 0,
              wins <= Self.maximumSamples - ties,
              wins + ties <= Self.maximumSamples - losses else {
            throw CourseMonteCarloError.invalidReportCounts
        }
        let total = wins + ties + losses
        guard (2...Self.maximumSamples).contains(total) else {
            throw CourseMonteCarloError.invalidReportCounts
        }
        self.seed = seed
        self.wins = wins
        self.ties = ties
        self.losses = losses
    }

    public var samples: Int { wins + ties + losses }
    public var method: String {
        "SplitMix64 / rejection sampling v1. Равномерные допустимые runout без возвращения внутри пробы; независимые пробы с повторениями"
    }
    public var meanPercent: Double { mean * 100 }
    public var standardErrorPP: Double { standardError * 100 }
    public var lower95Percent: Double { max(0, (mean - 1.96 * standardError) * 100) }
    public var upper95Percent: Double { min(100, (mean + 1.96 * standardError) * 100) }

    private var mean: Double {
        (Double(wins) + Double(ties) * 0.5) / Double(samples)
    }

    /// Unbiased sample variance for X ∈ {0, 0.5, 1}, divided by √N.
    private var standardError: Double {
        let n = Double(samples)
        let sumSquares = Double(wins) + Double(ties) * 0.25
        let variance = max(0, (sumSquares - n * mean * mean) / (n - 1))
        return sqrt(variance / n)
    }
}

public enum CourseMonteCarlo {
    /// SplitMix64 plus unbiased rejection sampling; frozen algorithm v1.
    private static func drawIndex(count: Int, generator: inout SeededGenerator) -> Int {
        let bound = UInt64(count)
        let threshold = (0 &- bound) % bound
        var value = generator.next()
        while value < threshold { value = generator.next() }
        return Int(value % bound)
    }
    /// Samples allowed runouts uniformly. A turn question draws one remaining
    /// card; a flop question draws an ordered pair, whose board evaluation is
    /// order independent. The generator is local to this call and seed-stable.
    public static func sample(
        _ question: KnownHandEquityQuestion,
        samples: Int,
        seed: UInt64
    ) throws -> CourseMonteCarloReport {
        guard (2...CourseMonteCarloReport.maximumSamples).contains(samples) else {
            throw CourseMonteCarloError.invalidSampleCount
        }

        let known = Set(question.hero + question.opponent + question.board)
        let remaining = (0..<52).map(Card.init(id:)).filter { !known.contains($0) }
        var generator = SeededGenerator(state: seed)
        var wins = 0
        var ties = 0
        var losses = 0

        for _ in 0..<samples {
            try Task.checkCancellation()
            let runout: [Card]
            if question.board.count == 4 {
                runout = [remaining[drawIndex(count: remaining.count, generator: &generator)]]
            } else {
                let firstIndex = drawIndex(count: remaining.count, generator: &generator)
                let secondRaw = drawIndex(count: remaining.count - 1, generator: &generator)
                let secondIndex = secondRaw >= firstIndex ? secondRaw + 1 : secondRaw
                runout = [remaining[firstIndex], remaining[secondIndex]]
            }

            let hero = HandEvaluator.best(of: question.hero + question.board + runout)
            let opponent = HandEvaluator.best(of: question.opponent + question.board + runout)
            if hero == opponent { ties += 1 }
            else if hero > opponent { wins += 1 }
            else { losses += 1 }
        }

        return try CourseMonteCarloReport(seed: seed, wins: wins, ties: ties, losses: losses)
    }
}

public enum CourseEstimateMath {
    public static func rake(pot: Double, rate: Double, cap: Double) throws -> Double {
        guard pot.isFinite, rate.isFinite, cap.isFinite, pot >= 0, cap >= 0,
              (0...1).contains(rate) else { throw CourseMonteCarloError.invalidReportCounts }
        return min(pot * rate, cap)
    }
    public static func callEV(equity: Double, finalPot: Double, call: Double) throws -> Double {
        guard equity.isFinite, (0...1).contains(equity), finalPot.isFinite, call.isFinite,
              finalPot > 0, call >= 0, call <= finalPot else { throw CourseMonteCarloError.invalidReportCounts }
        return equity * finalPot - call
    }
    public static func futureAdjustment(equity: Double, winPayment: Double, winChance: Double,
                                        lossPayment: Double, lossChance: Double) throws -> Double {
        guard [equity, winChance, lossChance].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              [winPayment, lossPayment].allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw CourseMonteCarloError.invalidReportCounts }
        let result = equity * winChance * winPayment - (1 - equity) * lossChance * lossPayment
        guard result.isFinite else { throw CourseMonteCarloError.invalidReportCounts }
        return result
    }
}

public extension FoundationLesson {
    /// M05–M06 lessons use frozen, typed inputs. The Monte Carlo example is a
    /// recorded demonstration; opening the catalog never starts a simulation.
    static let recordedEquityReport = try! CourseMonteCarloReport(seed: 20_261_021, wins: 18_310, ties: 0, losses: 1_690)
    static let estimationExercises: [FoundationExercise] = [
        .init(
            id: "E.foundation.t10.recorded-mean", topicID: .t10, title: "Записанная оценка Monte Carlo", purpose: .concept,
            context: [
                "Cash heads-up, рейк 0; Hero A♠ A♥ против Villain K♠ K♥; flop 2♠ 7♥ 9♦.",
                "Записанная демонстрация использует seed 20261021 и N = 20 000 независимых проб.",
                "Внутри пробы две turn/river-карты выбираются равномерно без возвращения; между пробами runout может повторяться.",
                "Выплата X: победа 1 банка, ничья 0,5 банка, поражение 0 банков. Ответ округлите до 0,01 п.п."
            ],
            question: "Какой средний процент банка показывает записанная демонстрация?",
            answer: .number(value: recordedEquityReport.meanPercent, tolerance: 0.01),
            explanation: [
                "Записанный W/T/L подставляется в (W + T / 2) / N × 100.",
                "Это оценка Monte Carlo: она описывает данный seed, алгоритм и N; точный перебор хранится отдельно.",
                "W/T/L = 18 310 / 0 / 1 690. Средняя доля банка: 18 310 / 20 000 × 100 = 91,55 %."
            ],
            typicalError: "Назвать результат симуляции точным перебором или считать ничью полной победой.",
            term: "Monte Carlo", definition: "Оценка среднего по случайным допустимым пробам.", example: "20 000 случайных runout дают среднюю выплату X, а не список всех 990 пар.",
            method: "Зафиксируйте seed, N, правило выборки и выплату X; затем покажите W/T/L, среднее, SE и интервал.",
            assumptions: "Обе руки и flop известны; один общий банк; рейк и дальнейшие решения исключены. Приведён записанный прогон алгоритма SplitMix64/rejection v1; точный перебор 907/990 даёт 91,61616 %.",
            resultKind: .monteCarlo,
            diagram: [.init("N", "20 000"), .init("X", "0 / 0,5 / 1"), .init("Runout", "2 карты без возвращения в пробе")],
            cards: [Card(id: 12), Card(id: 25), Card(id: 11), Card(id: 24), Card(id: 0), Card(id: 18), Card(id: 33)],
            simulation: recordedEquityReport, researchAnchor: "nlhe-complete-knowledge-map.md#t10"
        ),
        .init(
            id: "E.foundation.t10.four-times-n", topicID: .t10, title: "Размер выборки и SE", purpose: .transfer,
            context: ["Метод и распределение выплат X не меняются.", "Размер независимой выборки увеличили с N = 10 000 до N = 40 000."],
            question: "Во сколько раз станет меньше SE среднего?", answer: .number(value: try! CourseEstimateMath.rake(pot: 40, rate: 0.05, cap: 3), tolerance: 0.001),
            explanation: ["SE меняется как 1 / √N.", "√(40 000 / 10 000) = 2.", "Поэтому SE станет в 2 раза меньше."],
            typicalError: "Ожидать уменьшение SE в четыре раза вместе с N.", term: "Стандартная ошибка", definition: "Оценка разброса среднего при повторении одинаковой процедуры выборки.", example: "Увеличение N в четыре раза уменьшает SE вдвое.", method: "Сравните √N, сохранив одинаковые единицы выплат и способ отбора.", assumptions: "Пробы независимы и имеют сопоставимое распределение X; изменение range меняет и среднее, и дисперсию.", resultKind: .conditionalModel,
            diagram: [.init("Было", "N = 10 000"), .init("Стало", "N = 40 000"), .init("SE", "÷ √4 = ÷ 2")], researchAnchor: "nlhe-complete-knowledge-map.md#t10"
        ),
        .init(
            id: "E.foundation.t10.ties-variance", topicID: .t10, title: "Ничья в дисперсии оценщика", purpose: .boundary,
            context: ["В heads-up пробах возможны победа, ничья и поражение.", "Выплата X задана как 1, 0,5 или 0 банка соответственно."],
            question: "Какую выборочную дисперсию используйте для SE среднего?", answer: .choice(options: ["Биномиальную только для W/L", "Выборочную дисперсию значений X = 0, 0,5, 1", "Дисперсию рангов карт"], correct: 1),
            explanation: ["Ничья даёт половину банка и образует третье значение выплаты.", "SE = s / √N, где s² считают по фактическим X.", "Биномиальная формула подходит лишь при явно бинарной выплате."],
            typicalError: "Свести ничьи к победам или поражениям без изменения модели выплаты.", term: "Выборочная дисперсия", definition: "Несмещённая оценка разброса наблюдённых выплат вокруг их среднего.", example: "Для X = 0, 0,5, 1 берут Σ(X − mean)² / (N − 1).", method: "Сначала задайте единицы X, затем считайте s² и SE в долях банка; в интерфейсе переводите SE в п.п.", assumptions: "Один общий heads-up банк; одна проба даёт одну выплату X.", resultKind: .conditionalModel,
            diagram: [.init("Поражение", "0"), .init("Ничья", "0,5"), .init("Победа", "1")], researchAnchor: "nlhe-complete-knowledge-map.md#t10"
        ),

        .init(
            id: "E.foundation.t14.direct-ev", topicID: .t14, title: "Прямой EV до будущей улицы", purpose: .concept,
            context: ["FUTURE-1: cash heads-up, turn; Hero 8♠ 8♥, board 9♣ 9♦ 9♥ 2♣.", "Диапазон Villain: 7♠ 7♥ с весом 1 и 9♠ 3♦ с весом 4. Все 44 river в каждой ветви учтены; equity Hero = 20 %.", "Банк до ставки 80, цена call 20, итог после call 120. Рейк 0; будущих платежей пока нет."],
            question: "Каков EV call до будущих платежей, в фишках?", answer: .number(value: try! CourseEstimateMath.callEV(equity: 0.2, finalPot: 120, call: 20), tolerance: 0.001),
            explanation: ["EV = 0,20 × 120 − 20.", "24 − 20 = 4 фишки.", "Это точная арифметика заданных входов FUTURE-1."],
            typicalError: "Вычесть прошлые вложения или подставить 8♠8♥ как победу против всего диапазона.", term: "Прямой EV", definition: "Ожидаемый результат текущего решения, когда последующие выплаты заданы нулевыми.", example: "20 % от банка 120 дают 24; после цены 20 остаётся 4.", method: "Зафиксируйте equity, итоговый банк и дополнительную цену; прошлые вложения остаются вне точки решения.", assumptions: "Полная условная модель FUTURE-1 задаёт руки, веса 1:4, 44 river, один общий банк, рейк 0. После колла у обоих остаётся по 80 фишек; будущий платёж 30 доступен.", resultKind: .conditionalModel,
            diagram: [.init("Equity", "20 %"), .init("Итоговый банк", "120"), .init("Цена", "20"), .init("EV", "+4")], cards: [Card(id: 6), Card(id: 19), Card(id: 46), Card(id: 33), Card(id: 20), Card(id: 39)], researchAnchor: "nlhe-complete-knowledge-map.md#t14"
        ),
        .init(
            id: "E.foundation.t14.future-payments", topicID: .t14, title: "Reverse implied odds в FUTURE-1", purpose: .transfer,
            context: ["Тот же полный паспорт FUTURE-1: equity 20 %, банк до ставки 80, call 20, итоговый банк 120.", "Дополнительная учебная политика: при выигрышной ветви Hero получает ещё 30 с вероятностью 0,5; при проигрышной сам платит ещё 30 с вероятностью 0,5.", "Собственная добавленная сумма в выигрышной ветви возвращается в выплате. Все суммы указаны в фишках; рейк 0."],
            question: "Каков общий EV call после этих будущих ветвей, в фишках?", answer: .number(value: try! CourseEstimateMath.callEV(equity: 0.2, finalPot: 120, call: 20) + CourseEstimateMath.futureAdjustment(equity: 0.2, winPayment: 30, winChance: 0.5, lossPayment: 30, lossChance: 0.5), tolerance: 0.001),
            explanation: ["Прямой EV равен 4.", "Изменение: 0,2 × 0,5 × 30 − 0,8 × 0,5 × 30 = −9.", "4 − 9 = −5 фишек."],
            typicalError: "Приписать Hero весь оставшийся стек как гарантированную выплату или забыть проигрышную ветвь.", term: "Reverse implied odds", definition: "Будущие ожидаемые потери, которые уменьшают результат текущего решения.", example: "Редкая победная доплата +3 и частая потеря −12 дают суммарно −9.", method: "Отдельно запишите вероятность, направление и сумму каждой будущей ветви; затем сложите с прямым EV.", assumptions: "Вероятности оплаты 0,5 заданы учебной моделью, они не выводятся из поведения бота или реального поля.", resultKind: .conditionalModel,
            diagram: [.init("Прямой EV", "+4"), .init("Win-добавка", "+3"), .init("Lose-добавка", "−12"), .init("Итог", "−5")], researchAnchor: "nlhe-complete-knowledge-map.md#t14"
        ),
        .init(
            id: "E.foundation.t14.future-limit", topicID: .t14, title: "Граница implied odds", purpose: .boundary,
            context: ["В FUTURE-1 будущая оплата 30 и вероятность 0,5 записаны явно как учебные входы.", "Hero и Villain имеют достаточные остатки для этих ветвей; реальная стратегия после river не моделируется."],
            question: "Что описывает число −5 в этой задаче?", answer: .choice(options: ["Гарантированный результат любой раздачи с парой восьмёрок", "Точный результат только заданных вероятностей будущих выплат", "Точный equity всех диапазонов cash-игры"], correct: 1),
            explanation: ["Карты и веса дают заданную equity, а будущие платежи задаёт условная политика.", "Число −5 точно для всех перечисленных входов вместе.", "Другой размер, стек, позиция или частота оплаты требуют нового дерева."],
            typicalError: "Перенести учебную вероятность оплаты на неизвестного соперника как доказанный факт.", term: "Условная модель", definition: "Расчёт с явно заданными допущениями о событиях, которые карты сами не определяют.", example: "Вероятность 0,5 оплаты — вход модели, а не свойство конкретной руки.", method: "Покажите карту, диапазон, веса, стек, сумму, вероятность и момент платежа рядом с результатом.", assumptions: "FUTURE-1 полностью задаёт только эту игрушечную future-line; стратегическая рекомендация из неё не выводится.", resultKind: .conditionalModel,
            diagram: [.init("Карты и веса", "заданы"), .init("Будущая оплата", "30 при p = 0,5"), .init("Результат", "только для FUTURE-1")], researchAnchor: "nlhe-complete-knowledge-map.md#t14"
        ),

        .init(
            id: "E.foundation.t15-rake-small-pot", topicID: .t15, title: "Рейк ниже cap", purpose: .concept,
            context: ["Учебный cash-тариф: rate = 5 %, cap = 3 фишки.", "Eligible pot при showdown равен 40 фишек. Округление отсутствует."],
            question: "Какой рейк удерживает модель, в фишках?", answer: .number(value: try! CourseEstimateMath.rake(pot: 40, rate: 0.05, cap: 3), tolerance: 0.001),
            explanation: ["rate × pot = 0,05 × 40 = 2.", "min(2, 3) = 2.", "Чистый банк игрокам после рейка равен 38."],
            typicalError: "Всегда брать cap 3, хотя процент от банка меньше.", term: "Rake cap", definition: "Верхняя граница комиссии в заданном тарифе.", example: "5 % от 40 равно 2 и остаётся ниже cap 3.", method: "Сначала вычислите rate × eligible pot, затем примените min с cap; подпишите единицы фишек.", assumptions: "Условный cash-тариф; eligibility, момент удержания и округление заданы этой задачей.", resultKind: .conditionalModel,
            diagram: [.init("Eligible pot", "40 фишек"), .init("5 %", "2 фишки"), .init("Cap", "3 фишки"), .init("Rake", "2 фишки")], researchAnchor: "nlhe-complete-knowledge-map.md#t15"
        ),
        .init(
            id: "E.foundation.t15-rake-cap", topicID: .t15, title: "Cap на большем банке", purpose: .transfer,
            context: ["Тот же учебный cash-тариф: rate = 5 %, cap = 3 фишки.", "Eligible pot при showdown равен 100 фишек. Округление отсутствует."],
            question: "Какой рейк удерживает модель, в фишках?", answer: .number(value: try! CourseEstimateMath.rake(pot: 100, rate: 0.05, cap: 3), tolerance: 0.001),
            explanation: ["0,05 × 100 = 5.", "min(5, 3) = 3.", "Cap ограничивает комиссию сверху."],
            typicalError: "Удержать 5 фишек и пропустить cap.", term: "Eligible pot", definition: "Часть банка, к которой по данному тарифу применяется рейк.", example: "В этой учебной модели eligible pot равен указанному showdown-банку.", method: "Покажите gross pot, ставку и cap до расчёта net pot.", assumptions: "Тариф применим к заданному cash showdown; реальные правила зависят от рума, лимита и юрисдикции.", resultKind: .conditionalModel,
            diagram: [.init("Gross pot", "100"), .init("5 %", "5"), .init("Cap", "3"), .init("Rake", "3")], researchAnchor: "nlhe-complete-knowledge-map.md#t15"
        ),
        .init(
            id: "E.foundation.t15-net-threshold", topicID: .t15, title: "Порог колла после рейка", purpose: .boundary,
            context: ["Cash heads-up. До решения P + B = 150 фишек; Hero доплачивает C = 50.", "При showdown удерживается рейк 3 фишки из итогового gross pot 200. Чистая выплата при выигрыше = 197.", "Один общий банк, без ничьих и будущих ставок. Ответ в процентах, округлите до 0,01."],
            question: "Какая equity нужна для нулевого EV call?", answer: .number(value: 100 * 50 / 197, tolerance: 0.01),
            explanation: ["Порог = цена call / чистая выплата при выигрыше.", "50 / 197 × 100 = 25,38 %.", "Знаменатель 197 включает вклад Hero и вычтенный рейк; gross 200 дал бы другой порог."],
            typicalError: "Делить 50 на 200 и игнорировать удержанный рейк.", term: "Net payout", definition: "Выплата после комиссии, доступная победителю в заданной модели.", example: "Gross 200 минус rake 3 даёт net 197.", method: "Сначала зафиксируйте момент рейка, затем замените gross payout на net payout в пороге call.", assumptions: "Рейк удерживается только при showdown ровно в 3 фишки; split pot, no-flop-no-drop и округление исключены.", resultKind: .conditionalModel,
            diagram: [.init("Gross итог", "200"), .init("Rake", "−3"), .init("Net payout", "197"), .init("Порог", "50 / 197 = 25,38 %")], researchAnchor: "nlhe-complete-knowledge-map.md#t15"
        ),

        .init(
            id: "E.foundation.t16-wald-se", topicID: .t16, title: "SE доли решений", purpose: .concept,
            context: ["В 100 заранее определённых независимых decisions 55 ответов признаны корректными.", "Метрика бинарная: X = 1 для корректного решения и X = 0 иначе; p̂ = 55 / 100 = 0,55.", "Используйте Wald-SE = √(p̂(1 − p̂) / N). Ответ в процентных пунктах, округлите до 0,01."],
            question: "Какова Wald-SE этой доли?", answer: .number(value: 100 * sqrt(0.55 * 0.45 / 100), tolerance: 0.01),
            explanation: ["p̂(1 − p̂) / N = 0,55 × 0,45 / 100.", "Корень равен 0,04975 в доле.", "В процентных пунктах это 4,97 п.п."],
            typicalError: "Сообщить 0,04975 п.п. и потерять перевод из доли в проценты.", term: "SE доли", definition: "Оценка разброса выборочной доли при повторении одинакового отбора.", example: "0,04975 доли равно 4,975 процентного пункта.", method: "Покажите p̂, N, формулу, единицы результата и правило округления.", assumptions: "Наблюдения независимы и сопоставимы; правильность задана заранее, selection bias отсутствует.", resultKind: .conditionalModel,
            diagram: [.init("Корректно / N", "55 / 100"), .init("p̂", "0,55"), .init("SE", "0,04975 = 4,97 п.п.")], researchAnchor: "nlhe-complete-knowledge-map.md#t16"
        ),
        .init(
            id: "E.foundation.t16-four-times-sample", topicID: .t16, title: "Больше решений, уже SE", purpose: .transfer,
            context: ["Распределение бинарной метрики и доля p̂ сохраняются.", "Размер независимой выборки увеличили с 100 до 400 decisions.", "Исходная SE равна 4,9749 п.п."],
            question: "Какой станет SE в п.п., округлите до 0,01?", answer: .number(value: 100 * sqrt(0.55 * 0.45 / 400), tolerance: 0.01),
            explanation: ["N увеличилось в четыре раза.", "SE уменьшается в √4 = 2 раза.", "4,9749 / 2 = 2,4875 п.п., после округления 2,49 п.п."],
            typicalError: "Разделить SE на четыре вместе с N.", term: "Размер выборки", definition: "Число наблюдений, включённых по одному определённому правилу отбора.", example: "100 и 400 сравнимы, когда метрика и правило отбора совпадают.", method: "Сначала проверяйте одинаковость метрики и отбора, затем применяйте зависимость 1 / √N.", assumptions: "Новые 300 decisions независимы и не выбраны по результату; это статистическая модель, а не оценка силы игрока.", resultKind: .conditionalModel,
            diagram: [.init("N", "100 → 400"), .init("Множитель N", "×4"), .init("SE", "4,97 → 2,49 п.п.")], researchAnchor: "nlhe-complete-knowledge-map.md#t16"
        ),
        .init(
            id: "E.foundation.t16-small-sample", topicID: .t16, title: "Граница малого N", purpose: .boundary,
            context: ["Игрок сделал 4 решения в одном и том же споте и все четыре оказались корректными.", "Позиция, стек и правило оценки не записаны; выборка не отделена от разбора результатов."],
            question: "Какой вывод поддерживает эта выборка?", answer: .choice(options: ["Навык доказан с точностью 100 %", "Нужно записать правило отбора и собрать сопоставимые независимые решения", "Можно применить результат ко всем форматам и стекам"], correct: 1),
            explanation: ["4 / 4 описывает только четыре наблюдения.", "Без позиции, стека и правила отбора данные не образуют переносимую оценку.", "Небольшая серия не отделяет навык, удачу и selection bias."],
            typicalError: "Выдать наблюдаемую долю за устойчивый профиль игрока.", term: "Selection bias", definition: "Смещение, возникающее когда в выборку попадают особые наблюдения, а не заранее определённый поток.", example: "Показанные раздачи после удачи не равны всем сыгранным спотам.", method: "До сбора данных зафиксируйте узел, формат, позицию, стек, метрику и N; затем показывайте интервал с ограничениями.", assumptions: "Задача проверяет границу статистического вывода; она не оценивает личный навык или финансовый результат.", resultKind: .definitions,
            diagram: [.init("Наблюдения", "4 / 4"), .init("Паспорт", "не записан"), .init("Вывод", "нужны сопоставимые данные")], researchAnchor: "nlhe-complete-knowledge-map.md#t16"
        )
    ]
}
