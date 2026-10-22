import Foundation

/// Exact arithmetic for small, fully specified Independent Chip Model lessons.
/// It models tournament prize equity; the six-max practice table remains cash practice.
public enum CourseICMError: Error, Equatable, Sendable {
    case invalidScenario
    case multipleEliminationsNeedPlacementRule
    case invalidProbability
}

public struct CourseICMSidePots: Equatable, Sendable {
    public let main: Double
    public let side: Double
    public let refund: Double
    public var total: Double { main + side + refund }
}

public enum CourseICM {
    private static func finiteSum(_ values: [Double]) -> Double? {
        var sum = 0.0
        for value in values {
            sum += value
            guard sum.isFinite else { return nil }
        }
        return sum
    }

    /// Enumerates finish orders for two through six players. A single zero stack is
    /// an already eliminated last-place player. Several simultaneous zero stacks
    /// need a tournament placement rule, so this teaching calculator rejects them.
    public static func prizeEquities(stacks: [Double], payouts: [Double]) throws -> [Double] {
        guard (2...6).contains(stacks.count), stacks.count == payouts.count,
              stacks.allSatisfy({ $0.isFinite && $0 >= 0 }),
              payouts.allSatisfy({ $0.isFinite && $0 >= 0 }),
              zip(payouts, payouts.dropFirst()).allSatisfy({ $0 >= $1 }),
              let stackTotal = finiteSum(stacks), stackTotal > 0,
              finiteSum(payouts) != nil else {
            throw CourseICMError.invalidScenario
        }
        let zeroes = stacks.indices.filter { stacks[$0] == 0 }
        guard zeroes.count <= 1 else { throw CourseICMError.multipleEliminationsNeedPlacementRule }

        let active = stacks.indices.filter { stacks[$0] > 0 }
        var equities = Array(repeating: 0.0, count: stacks.count)
        func enumerate(_ remaining: [Int], rank: Int, probability: Double) {
            if remaining.count == 1 {
                equities[remaining[0]] += probability * payouts[rank]
                return
            }
            let total = remaining.reduce(0.0) { $0 + stacks[$1] }
            for candidate in remaining {
                let next = remaining.filter { $0 != candidate }
                let chance = probability * (stacks[candidate] / total)
                enumerate(next, rank: rank + 1, probability: chance)
                equities[candidate] += chance * payouts[rank]
            }
        }
        enumerate(active, rank: 0, probability: 1)
        if let eliminated = zeroes.first { equities[eliminated] = payouts[payouts.count - 1] }
        return equities
    }

    public static func weightedPrizeEV(probabilities: [Double], prizes: [Double]) throws -> Double {
        guard probabilities.count == prizes.count, probabilities.count >= 2,
              probabilities.allSatisfy({ $0.isFinite && $0 >= 0 }), prizes.allSatisfy(\.isFinite),
              abs(probabilities.reduce(0, +) - 1) < 1e-12 else { throw CourseICMError.invalidProbability }
        var result = 0.0
        for (probability, prize) in zip(probabilities, prizes) {
            result += probability * prize
            guard result.isFinite else { throw CourseICMError.invalidScenario }
        }
        return result
    }

    public static func callThresholdPercent(fold: Double, win: Double, lose: Double) throws -> Double {
        let denominator = win - lose
        guard [fold, win, lose, denominator].allSatisfy(\.isFinite), win > fold, fold >= lose, denominator > 0 else {
            throw CourseICMError.invalidScenario
        }
        let result = (fold - lose) / denominator * 100
        guard result.isFinite else { throw CourseICMError.invalidScenario }
        return result
    }

    public static func bubbleFactor(fold: Double, win: Double, lose: Double) throws -> Double {
        let loss = fold - lose
        let gain = win - fold
        guard [fold, win, lose, loss, gain].allSatisfy(\.isFinite), win > fold, fold > lose, gain > 0 else {
            throw CourseICMError.invalidScenario
        }
        let result = loss / gain
        guard result.isFinite else { throw CourseICMError.invalidScenario }
        return result
    }

    public static func pureShoveFoldThresholdPercent(risk: Double, reward: Double) throws -> Double {
        let denominator = risk + reward
        guard risk.isFinite, reward.isFinite, denominator.isFinite, risk > 0, reward >= 0 else { throw CourseICMError.invalidScenario }
        let result = risk / denominator * 100
        guard result.isFinite else { throw CourseICMError.invalidScenario }
        return result
    }

    /// The disclosed three-player side-pot model from T50: A/B/C contributed 100/60/20.
    public static func sidePots(contributions: [Double]) throws -> CourseICMSidePots {
        guard contributions.count == 3, contributions.allSatisfy({ $0.isFinite && $0 >= 0 }),
              contributions[0] >= contributions[1], contributions[1] >= contributions[2] else {
            throw CourseICMError.invalidScenario
        }
        let main = contributions[2] * 3
        let side = (contributions[1] - contributions[2]) * 2
        let refund = contributions[0] - contributions[1]
        guard [main, side, refund].allSatisfy(\.isFinite), finiteSum([main, side, refund]) != nil else {
            throw CourseICMError.invalidScenario
        }
        return .init(main: main, side: side, refund: refund)
    }
}

public extension FoundationLesson {
    private static let r0Passport = [
        "Учебный MTT R0, 3 игрока: A BTN=48, B SB=31, C BB=21; blinds 0,5/1, ante 0, rake 0.",
        "A фолдит; B completes, C checks: банк 2, stacks 48/30/20. Flop и turn checks; river B checks, C shove 20, B call 20.",
        "B=AsQc, board Qd7c4h2s9d; C: QhQs с весом 1−q, JcTc с весом q. Payouts: 50/30/20 условных единиц.",
        "Terminal stacks A/B/C: fold 48/30/22; B win 48/52/0; B lose 48/10/42."
    ]
    private static let r1Passport = [
        "Учебный MTT R1, 3 игрока: A BTN=40, B SB=40, C BB=20; blinds 0,5/1, ante 0, rake 0.",
        "A фолдит; B completes, C checks: банк 2, B/C=39/19. Flop и turn checks; river B shove 39, C call покрытые 19, лишние 20 B возвращаются.",
        "C=AsQc, board Qd7c4h2s9d; B: QhQs с весом 1−q, JcTc с весом q. Payouts: 50/30/0 условных единиц.",
        "Terminal stacks A/B/C: fold 40/41/19; C win 40/20/40; C lose 40/60/0."
    ]
    static let icmExercises: [FoundationExercise] = [
        // MARK: T45 — R0 ICM and chip EV
        .init(id: "E.foundation.t45.r0-fold", topicID: .t45, title: "R0: ICM ценность фолда", purpose: .concept,
              context: r0Passport + ["ICM перечисляет вероятности мест из всех трёх стеков. Фишки и денежная ценность считаются раздельно."],
              question: "Введите ICM ценность B после фолда, округляя до 0,0001.", answer: .number(value: try! CourseICM.prizeEquities(stacks: [48, 30, 22], payouts: [50, 30, 20])[1], tolerance: 0.0001),
              explanation: ["ICM B: 30 % первого места; вероятность второго места складывается по возможным победителям.", "B первый: 30/100. B второй: (48/100)×(30/52)+(22/100)×(30/78)=47/130.", "B третий: 22/65. Ценность = 0,3×50+(47/130)×30+(22/65)×20 = 32,6154 условных единицы.", "Это prize EV, а не число фишек B."], typicalError: "Подменить prize EV стеком 30 или cash chip EV.", term: "ICM", definition: "Модель, превращающая все стеки и payout ladder в ожидаемую ценность мест.", example: "При 30 фишках B имеет ICM 32,6154 из-за вероятностей всех мест.", method: "Перечислите порядок мест с вероятностями stack / sum stacks и умножьте на payouts.", assumptions: "Условная ICM-модель, 3 игрока, payouts 50/30/20, без будущей игры и bounty; вычисление точно внутри модели.", resultKind: .conditionalModel, diagram: [.init("Стек B", "30 chips"), .init("Payouts", "50 / 30 / 20"), .init("ICM B", "32,6154")], researchAnchor: "nlhe-complete-knowledge-map.md#t45"),
        .init(id: "E.foundation.t45.r0-call-50", topicID: .t45, title: "R0: call при 50 % win", purpose: .transfer,
              context: r0Passport + ["Вероятности outcome: win 50 %, tie 0 %, lose 50 %. Win/lose описывают исход раздачи, а не готовую денежную equity.", "Chip EV call=.5×42−20=+1 chip; ICM сравнивает prize EV leaves с fold state."],
              question: "Введите ICM EV колла B, округляя до 0,0001.", answer: .number(value: try! CourseICM.weightedPrizeEV(probabilities: [0.5, 0.5], prizes: [40.4, 24.647214854111405]), tolerance: 0.0001),
              explanation: ["Сначала ICM каждого terminal state: Uwin=40,4 и Ulose=24,6472.", "Знаменатель вероятностей здесь 50 % + 50 % = 100 %.", "0,5×40,4 + 0,5×24,6472 = 32,5236074, ниже fold 32,6153846 на 0,0917772 payout units.", "Chip EV того же call: 0,5×42−20=+1 chip. Метрики имеют разные единицы и дают разный вывод."], typicalError: "Назвать 50 % showdown win 50 % денежной ценности или сравнить payout units с 20 фишками колла.", term: "Terminal state", definition: "Полный вектор стеков после одного исхода раздачи.", example: "Проигрыш R0 оставляет B с 10, а C с 42.", method: "Рассчитайте ICM для каждого terminal state, затем взвесьте по win/tie/lose; chip EV подпишите отдельной строкой.", assumptions: "Условная ICM-модель R0; ties=0; все стеки, payouts и исходы заданы; точная арифметика модели.", resultKind: .conditionalModel, diagram: [.init("Chip EV", "+1 chip"), .init("ICM call", "32,5236074"), .init("ICM fold", "32,6153846"), .init("Разница", "−0,0917772 payout units")], researchAnchor: "nlhe-complete-knowledge-map.md#t45"),
        .init(id: "E.foundation.t45.tie-leaf", topicID: .t45, title: "R0: отдельная ветвь tie", purpose: .boundary,
              context: r0Passport + ["Вариант R0 с новой рукой C для ничьей: B=AsQc, C=AcQh. Конечные стеки A/B/C=48/31/21; Utie(B)=32,9855890944 условной единицы.", "В новом диапазоне веса: JcTc — 45 %, AcQh — 10 %, QhQs — 45 %. Это выигрыш, ничья и проигрыш B; сумма вероятностей равна 1."],
              question: "Как собрать ICM EV колла?", answer: .choice(options: ["q × Uwin + (1−q) × Ulose", "w × Uwin + t × Utie + l × Ulose, где w+t+l=1", "Showdown equity × stack B"], correct: 1),
              explanation: ["Ничья создаёт состояние 48/31/21. ICM даёт B: 0,31×50 + (0,48×31/52+0,21×31/79)×30 + оставшаяся вероятность×20 = 32,9855890944.", "Win/tie/lose — три вероятности исходов; их знаменатель равен 1.", "Одна showdown equity с половиной tie не заменяет денежные листья."], typicalError: "Спрятать tie внутри q и применить формулу двух ветвей.", term: "Ветвь tie", definition: "Отдельный исход с собственным распределением стеков и ICM ценностью.", example: "При t=10 % сначала строят stacks после дележа банка.", method: "Проверьте сумму w+t+l, рассчитайте ICM каждого листа и сложите взвешенно.", assumptions: "Граница условной ICM-модели; правила дележа и odd chip должны быть заданы отдельно.", resultKind: .conditionalModel, diagram: [.init("Выигрыш 45 %", "0,45 × 40,4"), .init("Ничья 10 %", "0,10 × 32,9855890944"), .init("Проигрыш 45 %", "0,45 × 24,6472148541")], researchAnchor: "nlhe-complete-knowledge-map.md#t45"),

        // MARK: T46 — risk premium
        .init(id: "E.foundation.t46.bubble-factor", topicID: .t46, title: "R0: bubble factor", purpose: .concept,
              context: r0Passport + ["R0 relative to fold: Ufold=32,6153846, Uwin=40,4, Ulose=24,6472149.", "Конвенция урока: BF = (Ufold−Ulose) / (Uwin−Ufold)."],
              question: "Введите bubble factor, округляя до 0,0001.", answer: .number(value: try! CourseICM.bubbleFactor(fold: 32.61538461538461, win: 40.4, lose: 24.647214854111405), tolerance: 0.0001),
              explanation: ["Потеря L=7,9682; выгода G=7,7846.", "BF=L/G=1,0236.", "Это отношение денежных изменений в указанном дереве."], typicalError: "Добавить BF как процент к equity или назвать его постоянным свойством стека.", term: "Bubble factor", definition: "Отношение денежной потери при проигрыше к выгоде при выигрыше относительно fold state.", example: "В R0 L немного больше G.", method: "Зафиксируйте fold/win/lose leaves, найдите L и G, затем разделите L на G.", assumptions: "Условная ICM-модель R0 и записанная конвенция BF; стратегия и общая частота не выводятся.", resultKind: .conditionalModel, diagram: [.init("L", "32,6154 − 24,6472"), .init("G", "40,4 − 32,6154"), .init("BF", "L / G")], researchAnchor: "nlhe-complete-knowledge-map.md#t46"),
        .init(id: "E.foundation.t46.threshold", topicID: .t46, title: "Порог по gain и loss", purpose: .transfer,
              context: r0Passport + ["В R0 относительно фолда: выгода G=7,7846153846, потеря L=7,9681697613; ничьи исключены.", "Вероятность выигрыша q, проигрыша 1−q; ценности выражены в условных единицах выплат."],
              question: "Введите требуемую вероятность win в процентах.", answer: .number(value: try! CourseICM.callThresholdPercent(fold: 32.61538461538461, win: 40.4, lose: 24.647214854111405), tolerance: 0.01),
              explanation: ["Безразличие: q×G=(1−q)×L.", "q = L/(G+L) = 7,9681697613/(7,7846153846+7,9681697613).", "Получаем 50,58 %; знаменатель содержит сумму денежной выгоды и потери."], typicalError: "Вычесть 3 из 50 % или принять BF за процент.", term: "Risk premium", definition: "Разница между ICM и chip-EV порогом в конкретной модели.", example: "В R0 порог выигрыша равен 50,58 %.", method: "Покажите gain, loss и знаменатель G+L; ties добавляют отдельный leaf.", assumptions: "Условная двухветвевая модель, tie=0; это арифметический пример, не chart диапазона.", resultKind: .conditionalModel, diagram: [.init("Выигрыш", "q × 7,7846153846"), .init("Проигрыш", "(1−q) × 7,9681697613"), .init("Знаменатель", "7,7846153846 + 7,9681697613")], researchAnchor: "nlhe-complete-knowledge-map.md#t46"),
        .init(id: "E.foundation.t46.tie-limit", topicID: .t46, title: "Граница bubble factor", purpose: .boundary,
              context: r0Passport + ["В раздаче есть win, tie и lose с различными terminal stacks.", "Даны Ufold, Uwin и Ulose, но отсутствует Utie."],
              question: "Какой вход требуется перед расчётом порога?", answer: .choice(options: ["Только bubble factor прошлого спота", "ICM ценность Utie и вероятность tie", "Только число блайндов"], correct: 1),
              explanation: ["Tie меняет финальные стеки и может иметь собственную ICM ценность.", "Формула двух ветвей действует при tie=0.", "Payout ladder и все field stacks остаются входами ICM."], typicalError: "Использовать BF из двух ветвей при неописанной ничьей.", term: "Risk premium модели", definition: "Порог, зависящий от конкретных leaves, payouts и стеков.", example: "После split pot сначала пересчитывают все финальные stacks.", method: "Добавьте Utie в EV-дерево и проверьте, что w+t+l=1.", assumptions: "Граница модели; ICM не оценивает skill edge и будущие уровни блайндов.", resultKind: .conditionalModel, diagram: [.init("Нужен leaf", "Utie"), .init("Вероятности", "w + t + l = 1"), .init("Порог", "из полного дерева")], researchAnchor: "nlhe-complete-knowledge-map.md#t46"),
        .init(id: "E.foundation.t46.r0-risk-premium", topicID: .t46, title: "R0: разница ICM и chip EV", purpose: .transfer,
              context: r0Passport + ["Для B: Ufold=32,6153846, Uwin=40,4, Ulose=24,6472149; tie=0.", "ICM threshold=(Ufold−Ulose)/(Uwin−Ulose). Chip-EV threshold=20/42: цена call 20, итоговый банк 42."],
              question: "Введите model risk premium в процентных пунктах, округляя до 0,0001.", answer: .number(value: try! CourseICM.callThresholdPercent(fold: 32.61538461538461, win: 40.4, lose: 24.647214854111405) - 20 / 42 * 100, tolerance: 0.0001),
              explanation: ["ICM порог R0 равен 50,5826093 %.", "Chip-EV порог: 20 / 42 = 47,6190476 %.", "Разность 2,9635617 процентного пункта относится только к этому tree."], typicalError: "Считать разность 2,9635617 % универсальной надбавкой для любого турнира.", term: "Model risk premium", definition: "Разность ICM и chip-EV порогов в одном полном учебном дереве.", example: "В R0 payouts 50/30/20 делают риск проигрыша дороже выгоды выигрыша.", method: "Сначала рассчитайте оба порога из подписанных denominators, затем вычтите ICM minus chip EV.", assumptions: "Условная ICM-модель R0, ties=0, заданные stacks/payouts; exact arithmetic внутри модели, без рекомендаций диапазона.", resultKind: .conditionalModel, diagram: [.init("ICM", "50,5826093 %"), .init("Chip EV", "20 / 42 = 47,6190476 %"), .init("Premium", "2,9635617 п.п.")], researchAnchor: "nlhe-complete-knowledge-map.md#t46"),

        // MARK: T47 — R1 bubble and pay jumps
        .init(id: "E.foundation.t47.r1-fold", topicID: .t47, title: "R1: fold на bubble", purpose: .concept,
              context: r1Passport + ["C рискует 19 покрытых фишек на river; лишние 20 B возвращаются B."],
              question: "Введите ICM ценность C после фолда, округляя до 0,0001.", answer: .number(value: try! CourseICM.prizeEquities(stacks: [40, 41, 19], payouts: [50, 30, 0])[2], tolerance: 0.0001),
              explanation: ["Все 100 фишек поля и payouts 50/30/0 входят в ICM.", "Точный перебор даёт Ufold(C)=17,2610.", "Нулевой третий payout создаёт bubble pressure внутри модели."], typicalError: "Оценить C только по 19 фишкам или выдать B непокрытые фишки C.", term: "Pay jump", definition: "Разница соседних выплат; здесь переход с третьего на второе место стоит 30 единиц.", example: "В R1 третье место имеет payout 0.", method: "Сначала восстановите полный terminal stack vector, затем перечислите вероятности мест.", assumptions: "Условная ICM-модель R1, 3 игрока, payouts 50/30/0; точна арифметика модели.", resultKind: .conditionalModel, diagram: [.init("Stacks", "40 / 41 / 19"), .init("Payouts", "50 / 30 / 0"), .init("Ufold C", "17,2610")], researchAnchor: "nlhe-complete-knowledge-map.md#t47"),
        .init(id: "E.foundation.t47.r1-call-60", topicID: .t47, title: "R1: call при 60 % win", purpose: .transfer,
              context: r1Passport + ["Win=60 %, tie=0 %, lose=40 %. Uwin(C)=31; Ulose(C)=0."],
              question: "Введите ICM EV колла C, округляя до 0,01.", answer: .number(value: try! CourseICM.weightedPrizeEV(probabilities: [0.6, 0.4], prizes: [31, 0]), tolerance: 0.01),
              explanation: ["EV=0,60×31 + 0,40×0.", "Знаменатель вероятностей: 0,60+0,40=1.", "18,60 выше Ufold 17,2610 в заданной модели."], typicalError: "Сравнить 60 % с chip threshold 47,5 % и пропустить payouts.", term: "Покрывающий игрок", definition: "Игрок, чей stack позволяет покрыть риск оппонента в этом terminal tree.", example: "В R1 B рискует больше, а C может выиграть только покрытые 19.", method: "Для каждого outcome перепроверьте возврат непокрытых фишек, затем взвесьте ICM leaves.", assumptions: "Условная ICM-модель R1, ties=0; win probability задана, диапазон и стратегия не выводятся.", resultKind: .conditionalModel, diagram: [.init("Win 60 %", "31"), .init("Lose 40 %", "0"), .init("ICM EV", "18,60")], researchAnchor: "nlhe-complete-knowledge-map.md#t47"),
        .init(id: "E.foundation.t47.payout-limit", topicID: .t47, title: "Граница pay jump", purpose: .boundary,
              context: r1Passport + ["В R1 поменяли ladder payouts, оставив те же stacks и карты.", "Новый payout vector известен, но прежний порог 55,6807 % записан для 50/30/0."],
              question: "Какой расчёт корректен?", answer: .choice(options: ["Оставить прежний порог: карты не изменились", "Пересчитать ICM leaves и порог с новым payout vector", "Использовать только число BB C"], correct: 1),
              explanation: ["ICM включает payout ladder в каждом terminal leaf.", "Та же раздача с иными выплатами меняет gain и loss.", "Карты задают вероятности outcomes, а payouts задают их ценность."], typicalError: "Считать слово bubble фиксированным числом процентов.", term: "Payout ladder", definition: "Полный вектор призов по местам, включая нулевые выплаты.", example: "50/30/0 и 50/30/20 дают разные ICM values.", method: "Укажите новый vector, все stacks и terminal states; затем повторите перечисление.", assumptions: "Граница условной ICM-модели; blind pressure и будущие раздачи отсутствуют.", resultKind: .conditionalModel, diagram: [.init("Меняется", "payout vector"), .init("Пересчитать", "Ufold/Uwin/Ulose"), .init("Вывод", "новый порог")], researchAnchor: "nlhe-complete-knowledge-map.md#t47"),

        // MARK: T49 — push/fold tree
        .init(id: "E.foundation.t49.fold-threshold", topicID: .t49, title: "Push/fold: dead money", purpose: .concept,
              context: ["Учебная chip-EV модель MTT: риск shove 10 BB, uncontested reward 2,5 BB.", "При call hero имеет 0 equity; ICM, payouts и диапазоны здесь отсутствуют намеренно."],
              question: "Введите break-even fold frequency в процентах.", answer: .number(value: try! CourseICM.pureShoveFoldThresholdPercent(risk: 10, reward: 2.5), tolerance: 0.01),
              explanation: ["EV=F×2,5−(1−F)×10.", "Знаменатель F = risk + reward = 12,5 BB.", "10/12,5 = 80,00 %."], typicalError: "Делить риск на reward или считать 0-equity пример диапазонной рекомендацией.", term: "Dead money", definition: "Фишки, которые shove может забрать без showdown в указанной ветви.", example: "Анте увеличивает reward и меняет знаменатель.", method: "Подпишите risk и reward, покажите EV-ветви и разделите risk на их сумму.", assumptions: "Точная chip-EV арифметика искусственной zero-equity модели; без ICM и без стратегии диапазонов.", resultKind: .conditionalModel, diagram: [.init("Fold", "F × 2,5 BB"), .init("Call", "(1−F) × −10 BB"), .init("Знаменатель", "10 + 2,5")], researchAnchor: "nlhe-complete-knowledge-map.md#t49"),
        .init(id: "E.foundation.t49.call-tree", topicID: .t49, title: "Push/fold: ветвь колла", purpose: .transfer,
              context: ["Тот же shove: risk 10 BB, dead money 2,5 BB. Теперь при call задана showdown win probability 45 %.", "Потери и выигрыши при call зависят от effective stack, вкладов и terminal state."],
              question: "Какой дополнительный элемент нужен для EV shove?", answer: .choice(options: ["Только прежняя fold frequency", "Win и lose payoffs ветви call вместе с вероятностями", "Только название руки hero"], correct: 1),
              explanation: ["При call появляется showdown subtree с собственными payoffs.", "Одной fold frequency недостаточно для оценки ветви call.", "В tournament варианте payoffs должны быть ICM leaves, а не только chips."], typicalError: "Оставить формулу нулевой equity после появления 45 % win.", term: "EV-дерево", definition: "Явные ветви outcomes, вероятности и payoff каждого outcome.", example: "Shove EV включает fold и call; call далее делится на win/lose/tie.", method: "Проверьте сумму вероятностей на каждом узле и единицы payoff: chips или prize EV.", assumptions: "Условная модель; ranges и реальные shove charts отсутствуют, 45 % — заданный вход.", resultKind: .conditionalModel, diagram: [.init("Fold", "F × reward"), .init("Call → win", "(1−F)×q×payoff"), .init("Call → lose", "(1−F)×(1−q)×payoff")], researchAnchor: "nlhe-complete-knowledge-map.md#t49"),
        .init(id: "E.foundation.t49.icm-limit", topicID: .t49, title: "Push/fold: граница chip EV", purpose: .boundary,
              context: ["MTT bubble: stack, payouts и several terminal states присутствуют. Есть chip-EV порог 80 % из отдельного примера.", "Игровой стол приложения остаётся cash-practice 6-max; это только учебный турнирный сценарий."],
              question: "Какая метрика нужна для денежного решения на bubble?", answer: .choice(options: ["ICM EV по всем terminal stacks и payouts", "Только chip-EV порог 80 %", "Стек hero без поля остальных игроков"], correct: 0),
              explanation: ["Денежная ценность bubble зависит от всех field stacks и ladder.", "Chip EV измеряет ожидаемые фишки, prize EV — условную ценность выплат.", "Для ICM нужны win/tie/lose final states."], typicalError: "Перенести chip threshold в ICM без terminal states.", term: "Chip EV", definition: "Ожидаемая величина фишек без преобразования в турнирные выплаты.", example: "Одинаковый shove может иметь разный ICM EV при другой ladder.", method: "Сначала выберите cash/chip EV или ICM prize EV, затем заполните соответствующие входы.", assumptions: "Учебный MTT сценарий; ICM условен и не описывает будущую игру, поле или skill edge.", resultKind: .conditionalModel, diagram: [.init("Chip EV", "фишки"), .init("ICM EV", "payout units"), .init("Нужны", "stacks + payouts + leaves")], researchAnchor: "nlhe-complete-knowledge-map.md#t49"),

        // MARK: T50 — side pots and ICM leaves
        .init(id: "E.foundation.t50.accounting", topicID: .t50, title: "Три слоя взносов", purpose: .concept,
              context: ["Учебный MTT field состоит из A/B/C со стартовыми стеками 100/60/20; payouts 90/60/30 условных единиц, blinds/ante/rake=0.", "A/B/C внесли all-in 100/60/20 фишек. Main: 20×3; side: (60−20)×2; unmatched A возвращаются.", "Полные leaves: B получает оба слоя → A/B/C=40/140/0; C main и A side →120/0/60; split main A/C и A side →150/0/30."],
              question: "Введите сумму main pot, side pot и refund A.", answer: .number(value: try! CourseICM.sidePots(contributions: [100, 60, 20]).total, tolerance: 0),
              explanation: ["Main=60, side=80, refund=40.", "Знаменатель учёта — сумма всех взносов: 100+60+20.", "60+80+40=180 фишек; каждый leaf затем получает ICM по payouts 90/60/30."], typicalError: "Считать только contested 140 и потерять refund 40.", term: "Side pot", definition: "Слой банка, доступный только игрокам, внесшим вклад до его уровня.", example: "C участвует в main 60, но не в side 80.", method: "Разбейте взносы по уровням, подпишите eligible игроков и отдельно верните unmatched сумму.", assumptions: "Точный учёт заданных взносов без рейка; ICM использует full field 100/60/20 и payouts 90/60/30; правила odd chip и hand ranking заданы leaf." , resultKind: .conditionalModel, diagram: [.init("Main", "20 × 3 = 60"), .init("Side", "40 × 2 = 80"), .init("Refund A", "40"), .init("Total", "180")], researchAnchor: "nlhe-complete-knowledge-map.md#t50"),
        .init(id: "E.foundation.t50.split-leaves", topicID: .t50, title: "Side pot после дележа main", purpose: .transfer,
              context: ["Учебный MTT field A/B/C: initial stacks 100/60/20, payouts 90/60/30, blinds/ante/rake=0.", "Взносы A/B/C=100/60/20. Main 60 делят A и C: по 30. Side 80 выигрывает A. Refund 40 возвращён A.", "Этот terminal leaf A/B/C=150/0/30; другие leaves: 40/140/0 и 120/0/60."],
              question: "Введите итоговый стек A в этом terminal leaf.", answer: .number(value: 150, tolerance: 0),
              explanation: ["A получает 30 из main, 80 side и 40 refund.", "A=150, B=0, C=30; сумма 180 сохранена.", "ICM для leaf использует payouts 90/60/30 и назначение B последнего payout по явному одному zero stack."], typicalError: "Дать C часть side pot или потерять refund A.", term: "Eligible", definition: "Игрок, чьи внесённые фишки позволяют претендовать на конкретный слой банка.", example: "C не внёс уровень side и не может получить его часть.", method: "Сначала распределите каждый слой его eligible игрокам, проверьте сохранение суммы, затем стройте ICM leaf.", assumptions: "Точная бухгалтерия заданного tie; ICM условен, но точен внутри full field 100/60/20 и payouts 90/60/30.", resultKind: .conditionalModel, diagram: [.init("A main share", "30"), .init("A side + refund", "80 + 40"), .init("A final", "150")], researchAnchor: "nlhe-complete-knowledge-map.md#t50"),
        .init(id: "E.foundation.t50.field-limit", topicID: .t50, title: "Граница ICM после side pot", purpose: .boundary,
              context: ["Учебный MTT: A/B/C внесли 100/60/20, D фолдил раньше и сохраняет 70. После leaf C main и A side stacks A/B/C/D=120/0/60/70.", "Payouts 90/60/30/0, blinds/ante/rake=0. D не участвовал в main и side pots, но участвует в ICM field."],
              question: "Какой stack vector нужен для ICM после распределения pots?", answer: .choice(options: ["Только A/B/C, потому что D фолдил", "A/B/C/D: все оставшиеся стеки поля после terminal outcome", "Только победитель side pot"], correct: 1),
              explanation: ["ICM ценность мест зависит от всего поля, включая игрока вне showdown.", "D исключён из eligible списков банка, но входит в field stacks.", "Несколько нулевых stacks требуют явного tournament placement rule; калькулятор не назначает места по seat order."], typicalError: "Смешать eligible bank list с ICM field list.", term: "Field stack vector", definition: "Полный список стеков всех оставшихся игроков турнира после outcome.", example: "D с 70 фишками меняет вероятности мест A/B/C.", method: "Сначала примените pot rules, затем добавьте неучаствовавшие стеки и payout ladder в ICM.", assumptions: "Условная ICM-модель; 120/0/60/70 и payouts 90/60/30/0 заданы полностью, а simultaneous elimination требует отдельного правила.", resultKind: .conditionalModel, diagram: [.init("Bank eligible", "A / B / C"), .init("ICM field", "A / B / C / D"), .init("Нужны", "payouts + placement rule")], researchAnchor: "nlhe-complete-knowledge-map.md#t50"),
        .init(id: "E.foundation.t50.icm-after-leaf", topicID: .t50, title: "ICM после распределения layers", purpose: .transfer,
              context: ["Учебный MTT field A/B/C: initial stacks 100/60/20, payouts 90/60/30, blinds/ante/rake=0.", "После split main A/C и side A terminal stacks A/B/C=150/0/30. Единственный zero stack B получает последний payout 30 по задокументированному правилу.", "ICM перечисляет два порядка среди A/C: вероятности первого места 150/180 и 30/180."],
              question: "Введите ICM ценность A, округляя до 0,01 условных единиц.", answer: .number(value: try! CourseICM.prizeEquities(stacks: [150, 0, 30], payouts: [90, 60, 30])[0], tolerance: 0.01),
              explanation: ["A занимает первое место с вероятностью 150/180=5/6 и получает 90.", "При первом месте C, A получает второе место и 60: вероятность 30/180=1/6.", "5/6×90 + 1/6×60 = 85,00 условных единиц."], typicalError: "Приписать A 90 всегда или назначить B payout по seat order без правила zero stack.", term: "ICM leaf", definition: "Полный field stack vector после pot outcome, к которому применяется payout model.", example: "150/0/30 с payouts 90/60/30 даёт A 85, а не его стек 150.", method: "Сначала сохраните chip accounting, затем перечислите order среди положительных стеков и добавьте единственный eliminated payout.", assumptions: "Условная ICM-модель 3 игроков; один zero stack имеет явно заданное последнее место; точная арифметика внутри модели.", resultKind: .conditionalModel, diagram: [.init("A first", "150 / 180 × 90"), .init("A second", "30 / 180 × 60"), .init("ICM A", "85,00")], researchAnchor: "nlhe-complete-knowledge-map.md#t50")
    ]
}
