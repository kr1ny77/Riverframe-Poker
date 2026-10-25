import Foundation

/// Arithmetic for the disclosed M14–M15 teaching models. It never infers a
/// strategy from a report or an observation.
public enum CourseTheoryMathError: Error, Equatable, Sendable {
    case invalidInput
    case nonFiniteResult
}

public enum CourseTheoryMath {
    public static func mixedEV(probabilities: [Double], actionEVs: [Double]) throws -> Double {
        guard !probabilities.isEmpty, probabilities.count == actionEVs.count,
              probabilities.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              actionEVs.allSatisfy({ $0.isFinite }),
              abs(probabilities.reduce(0, +) - 1) < 1e-12 else { throw CourseTheoryMathError.invalidInput }
        let result = zip(probabilities, actionEVs).reduce(0) { $0 + $1.0 * $1.1 }
        guard result.isFinite else { throw CourseTheoryMathError.nonFiniteResult }
        return result
    }

    public static func loss(fromBest bestEV: Double, simplifiedEV: Double) throws -> Double {
        guard bestEV.isFinite, simplifiedEV.isFinite else { throw CourseTheoryMathError.invalidInput }
        let result = bestEV - simplifiedEV
        guard result.isFinite else { throw CourseTheoryMathError.nonFiniteResult }
        return result
    }

    public static func sampleRate(successes: Double, trials: Double) throws -> Double {
        guard successes.isFinite, trials.isFinite, trials >= 1, successes >= 0, successes <= trials,
              trials.rounded() == trials, successes.rounded() == successes else {
            throw CourseTheoryMathError.invalidInput
        }
        return successes / trials
    }

    /// Wilson interval used only to display uncertainty of a labelled sample.
    public static func wilson95(successes: Double, trials: Double) throws -> ClosedRange<Double> {
        let rate = try sampleRate(successes: successes, trials: trials)
        let z = 1.959963984540054
        let z2 = z * z
        let denominator = 1 + z2 / trials
        let center = (rate + z2 / (2 * trials)) / denominator
        let radius = z * sqrt((rate * (1 - rate) + z2 / (4 * trials)) / trials) / denominator
        guard center.isFinite, radius.isFinite else { throw CourseTheoryMathError.nonFiniteResult }
        return max(0, center - radius)...min(1, center + radius)
    }

    public static func frequenciesAreNormalized(_ frequencies: [Double]) -> Bool {
        !frequencies.isEmpty && frequencies.allSatisfy { $0.isFinite && (0...1).contains($0) }
            && abs(frequencies.reduce(0, +) - 1) < 1e-9
    }
}

public extension FoundationLesson {
    static let theoryExercises: [FoundationExercise] = [
        // MARK: T41
        theory("E.foundation.t41.equilibrium", .t41, "Равновесие и лучший ответ", .concept,
               ["Двухигроковая zero-sum toy game: игрок A выбирает Left/Right, игрок B — Up/Down одновременно.", "Payoff A: Left/Up=+1, Left/Down=−1, Right/Up=−1, Right/Down=+1; payoff B противоположен."],
               "Какой профиль описывает равновесие этой игры?", .choice(options: ["A всегда Left, B всегда Up", "Оба выбирают каждое действие с вероятностью 50 %", "A всегда Right, B всегда Down"], correct: 1),
               ["При 50/50 каждый чистый ответ даёт ожидаемый payoff 0.", "Одностороннее изменение не улучшает ожидание при фиксированной 50/50 политике соперника.", "В этой конкретной zero-sum игре exploitability равна 0: лучший ответ не получает добавочного EV."],
               "Перенести 50/50 из этой матрицы на poker-узел без одинаковых payoff и дерева.", "Равновесие", "Профиль стратегий, где ни один игрок не улучшает своё ожидание односторонней заменой стратегии в заданной игре.", "В matching-pennies матрице 50/50 защищает от лучшего чистого ответа.", "Опишите игроков, действия и все payoff; затем сравните текущую policy с лучшим ответом в той же игре.", "Точный расчёт в указанной двухигроковой zero-sum матрице. Poker tree, рейк и неполная информация требуют собственного паспорта.", .exact,
               ["A payoff", "+1 / −1"], ["Exploitability", "0 в этой матрице"], "nlhe-complete-knowledge-map.md#t41"),
        theory("E.foundation.t41.game-boundary", .t41, "Граница равновесной формулы", .transfer,
               ["Flop, P=100 BB, bet=100 BB. Hero имеет draw; после call остаются turn и river.", "Equity, future sizes, ranges и response policy не заданы."],
               "Какое действие с моделью корректно?", .choice(options: ["Применить 50 % как точную частоту flop", "Построить дерево с будущими EV и входами", "Назвать bet прибыльным без ranges"], correct: 1),
               ["River toy-formula фиксирует отсутствие будущих ветвей.", "На flop payoff меняют equity и будущие решения."],
               "Перенести одношаговый river расчёт на несколько улиц.", "Равновесная модель", "Модель, где вывод относится к точно указанной игре и её действиям.", "Одинаковые P и bet создают разное дерево на flop и river.", "Сверьте улицу, действия и terminal payoffs до переноса формулы.", "Понятийная граница: полноценная проверенная таблица требует паспорта решения.", .definitions,
               ["River", "одна ветвь"], ["Flop", "future EV"], "nlhe-complete-knowledge-map.md#t41"),
        theory("E.foundation.t41.exploit-boundary", .t41, "Граница ярлыка GTO", .boundary,
               ["В отчёте указана частота bet 62 %. Не приложены board, позиции, stacks, rake, ranges, sizes, tree или точность solve."],
               "Какой вывод корректен?", .choice(options: ["62 % — универсальная частота", "Число можно читать только вместе с паспортом модели", "62 % доказывает выигрыш"], correct: 1),
               ["Частота принадлежит конкретному дереву и его входам.", "Без входов нельзя воспроизвести или перенести вывод."],
               "Выдать частоту из одного отчёта за норму всех игр.", "Паспорт решения", "Набор входов, который определяет вычисляемое дерево.", "Rake и разрешённые sizes меняют дерево.", "Сохраняйте входы до чтения частот и EV.", "Проверенная таблица требует источник, версию и полный паспорт; здесь их нет.", .definitions,
               ["Частота", "62 %"], ["Паспорт", "неполный"], "nlhe-complete-knowledge-map.md#t41"),

        // MARK: T42
        theory("E.foundation.t42.passport", .t42, "Поля паспорта solver-отчёта", .concept,
               ["Есть board Q♠7♦2♣, позиции CO/BTN, stacks 100 BB, pot 6 BB и один bet size 75 % pot.", "Rake отсутствует в записи; ranges, разрешённые lines и точность solve отсутствуют."],
               "Можно ли воспроизвести отчёт?", .choice(options: ["Да, board и stack достаточно", "Нет: нужны rake, ranges, дерево и точность", "Да, если частоты округлены"], correct: 1),
               ["Tree строится из состояния, ranges и разрешённых линий.", "Rake и точность также влияют на интерпретацию EV."],
               "Считать screenshot достаточным описанием модели.", "Паспорт отчёта", "Проверяемая запись board, позиций, stacks, pot, rake, ranges, дерева, sizes и точности.", "Один board не раскрывает диапазоны и варианты ставок.", "Останавливайте разбор при отсутствии критического входа и фиксируйте пробел.", "Понятийная проверка полноты; стратегия не вычисляется.", .definitions,
               ["Есть", "board, stacks, size"], ["Нет", "rake, ranges, tree, accuracy"], "nlhe-complete-knowledge-map.md#t42"),
        theory("E.foundation.t42.one-factor", .t42, "Один фактор чувствительности", .transfer,
               ["Два отчёта используют CO/BTN, board Q♠7♦2♣, stacks100, одинаковые ranges/tree/sizes/accuracy.", "A: rake 0 %. B: rake 5 %. Частота bet отличается."],
               "Какое изменение можно проверить этим сравнением?", .choice(options: ["Влияние rake в указанной модели", "Влияние rake и board вместе", "Универсальную реакцию поля"], correct: 0),
               ["Все входы кроме rake зафиксированы.", "Разница относится к этой паре условных моделей."],
               "Одновременно изменить rake, sizes и board, а затем приписать сдвиг одному фактору.", "Sensitivity test", "Сравнение двух моделей с одним намеренно изменённым входом.", "A и B различаются только rake.", "Зафиксируйте паспорт A, копируйте его в B, затем измените один вход.", "Условная модель; чувствительность дерева не измеряет частоту человеческой ошибки.", .conditionalModel,
               ["A", "rake 0 %"], ["B", "rake 5 %"], "nlhe-complete-knowledge-map.md#t42"),
        theory("E.foundation.t42.merge-boundary", .t42, "Граница объединения отчётов", .boundary,
               ["Отчёт A: board Q♠7♦2♣ и зафиксированный range A содержит Q♠5♠, range B — Q♥5♥.", "Отчёт B: board Q♥7♦2♣ при тех же физических ranges. В A Q♠5♠ конфликтует с board, в B Q♥5♥ конфликтует с board."],
               "Можно ли усреднить частоты как один и тот же узел?", .choice(options: ["Да, ранги board совпали", "Нет: physical board и removal различаются", "Да, если среднее равно 50 %"], correct: 1),
               ["При одновременно переименованных мастях board и обоих ranges всей игры модели могут быть изоморфны.", "Здесь board меняется при закреплённых per-role ranges, поэтому допустимые combos различаются."],
               "Игнорировать масти и физически заданные ranges в отчёте о postflop диапазонах.", "Совместимость карт", "Проверка, что board и range описывают одни и те же физические карты.", "Q♠ и Q♥ исключают разные combos в закреплённых ranges ролей.", "Сравнивайте физические карты, ranges и tree; отдельно проверяйте возможную полную relabel-изоморфность.", "Понятийная граница; количественный эффект требует заданных ranges.", .definitions,
               ["A", "Q♠7♦2♣"], ["B", "Q♥7♦2♣"], "nlhe-complete-knowledge-map.md#t42"),

        // MARK: T43
        theory("E.foundation.t43.mixed-ev", .t43, "EV смешанного действия", .concept,
               ["Условная river-модель с фиксированной policy соперника. Для одного hand class Raise выбран с вероятностью 25 %, EV raise=8 BB.", "Call выбран с вероятностью 75 %, EV call=7 BB. Fold отсутствует; рейк=0. Равенство EV действий не задано."],
               "Введите EV mix в BB с точностью до 0,01.", .number(value: try! CourseTheoryMath.mixedEV(probabilities: [0.25, 0.75], actionEVs: [8, 7]), tolerance: 0.01),
               ["Вклад raise: 0,25×8=2 BB.", "Вклад call: 0,75×7=5,25 BB.", "EV mix=7,25 BB."],
               "Сложить EV без весов или назвать illustrative 25 % equilibrium mix.", "Смешанное действие", "Выбор действий с указанными вероятностями внутри заданной модели.", "25 % raise и 75 % call дают 7,25 BB при этих EV.", "Проверьте, что веса суммируются до 1, затем взвесьте EV каждого действия.", "Точная арифметика условных входов. Это иллюстративная policy против фиксированного соперника; при EV8 и EV7 она не доказывает равновесный mix.", .conditionalModel,
               ["Raise", "25 % × 8 = 2"], ["Call", "75 % × 7 = 5,25"], "nlhe-complete-knowledge-map.md#t43"),
        theory("E.foundation.t43.simplification-loss", .t43, "Цена упрощения mix", .transfer,
               ["Тот же условный узел: EV mix=7,25 BB, always-call EV=7 BB.", "Эти EV уже рассчитаны в одном и том же паспорте."],
               "Введите потерю always-call относительно mix в BB.", .number(value: try! CourseTheoryMath.loss(fromBest: 7.25, simplifiedEV: 7), tolerance: 0.01),
               ["Потеря=7,25−7=0,25 BB.", "Это сравнение конкретных двух политик в одном узле."],
               "Назвать 0,25 BB доказательством, что любой simplification приемлем.", "Потеря EV", "Разность EV двух явно заданных политик в одном и том же дереве.", "Always-call теряет 0,25 BB только в указанном узле.", "Сравнивайте политики с одинаковыми inputs и укажите единицы EV.", "Условная модель без оценки человеческой частоты исполнения.", .conditionalModel,
               ["Mix", "7,25 BB"], ["Always call", "7,00 BB"], "nlhe-complete-knowledge-map.md#t43"),
        theory("E.foundation.t43.frequency-boundary", .t43, "Граница частоты mix", .boundary,
               ["Отчёт показывает «raise 60 %, call 40 %». EV двух действий, hand class, board и tree отсутствуют."],
               "Что требуется до решения об упрощении?", .choice(options: ["Выбрать частое действие", "Получить EV, hand class и паспорт дерева", "Округлить до 50/50"], correct: 1),
               ["Частота без EV не показывает стоимость альтернативы.", "Разные комбинации могут иметь разные причины mix."],
               "Подменить вопрос EV только частотой действия.", "Допустимое упрощение", "Выбранная политика с измеренной потерей EV в заданной модели.", "60/40 без EV не определяет цену always-call.", "Сначала найдите единицы EV и диапазон рук, затем сравните выбранную policy.", "Понятийная задача; отчёт без паспорта не образует проверенную таблицу.", .definitions,
               ["Есть", "60/40"], ["Нужно", "EV + hand + passport"], "nlhe-complete-knowledge-map.md#t43"),

        // MARK: T44
        theory("E.foundation.t44.sample-rate", .t44, "Частота и размер выборки", .concept,
               ["В заметках есть 2 fold из 2 одинаково размеченных ситуаций BTN против BB.", "Ситуации определены одинаковыми позициями, board и size; отбор раздач всё ещё неизвестен."],
               "Введите наблюдаемую fold-частоту в процентах.", .number(value: try! CourseTheoryMath.sampleRate(successes: 2, trials: 2) * 100, tolerance: 0.01),
               ["2/2=100 % — описание этой малой выборки.", "Число не подтверждает устойчивую привычку."],
               "Превратить 2/2 в достоверный exploit.", "Наблюдаемая частота", "Доля отмеченных событий внутри определённой выборки.", "2 fold из 2 дают 100 % наблюдений.", "Пишите числитель, знаменатель и правила отбора до гипотезы.", "Точная арифметика счёта; устойчивость требует репрезентативной выборки и проверки.", .exact,
               ["Fold", "2"], ["Trials", "2"], "nlhe-complete-knowledge-map.md#t44"),
        theory("E.foundation.t44.interval", .t44, "Неопределённость 140 из 200", .transfer,
               ["Есть 140 fold из 200 размеченных ситуаций одного типа. Отбор, позиции и sizes сохранены.", "Используется Wilson 95 % интервал для доли; это статистическая модель наблюдений."],
               "Введите нижнюю границу Wilson 95 % в процентах с точностью до 0,1.", .number(value: try! CourseTheoryMath.wilson95(successes: 140, trials: 200).lowerBound * 100, tolerance: 0.1),
               ["Точка: 140/200=70 %.", "Wilson 95 % нижняя граница около 63,3 %.", "Интервал описывает модель выборки, а не причину fold."],
               "Назвать 70 % точной привычкой без отбора и разброса.", "Интервал доли", "Диапазон неопределённости доли при указанной статистической модели.", "140/200 дают точку 70 %, а не полную уверенность.", "Сохраняйте n и метод интервала рядом с оценкой.", "Условная статистическая модель: зависимости раздач, selection bias и смена условий могут нарушить интерпретацию.", .conditionalModel,
               ["Оценка", "70,0 %"], ["Wilson 95 %", "≈63,3–75,9 %"], "nlhe-complete-knowledge-map.md#t44"),
        theory("E.foundation.t44.lock-boundary", .t44, "Граница node-lock гипотезы", .boundary,
               ["Запись содержит 12 fold, но не содержит позиции, board, size или условий отбора.", "План — зафиксировать сопернику fold 100 % в модели и назвать это эксплуатацией."],
               "Какой следующий шаг корректен?", .choice(options: ["Сразу lock 100 %", "Собрать сопоставимые теги и сформулировать проверяемую гипотезу", "Считать 12 fold универсальными"], correct: 1),
               ["Lock изменяет допущение модели, а не доказывает поведение поля.", "После тегирования сравните baseline с lock на обучающей выборке, проведите sensitivity для нескольких разумных fold rates и проверьте гипотезу на отдельной выборке."],
               "Выдать небольшой несмешанный набор наблюдений за точный диапазон соперника.", "Node-lock гипотеза", "Явное условное предположение о действии в конкретном узле для проверки sensitivity.", "«BTN fold 12/20 на Q72r против 75 % c-bet» проверяемее, чем «оппонент много фолдит».", "Сначала зафиксируйте node passport, n и отбор; затем сравните baseline, несколько lock и отдельную проверочную выборку.", "Понятийная граница: приложение не строит solver и не подтверждает exploit без данных.", .definitions,
               ["Наблюдения", "теги отсутствуют"], ["Следующий шаг", "паспорт + гипотеза"], "nlhe-complete-knowledge-map.md#t44"),

        // MARK: T51
        theory("E.foundation.t51.normalization", .t51, "Проверка сумм частот", .concept,
               ["Hero facing bet в одном river-узле. Экспорт одного hand class: raise 30 %, call 50 %, fold 10 %.", "Все три легальных взаимоисключающих действия должны описывать одну и ту же массу этой руки в этом узле."],
               "Корректно ли нормированы частоты?", .choice(options: ["Да, сумма 90 % допустима", "Нет, сумма должна быть 100 %", "Да, fold можно не учитывать"], correct: 1),
               ["0,30+0,50+0,10=0,90.", "Потерянные 10 % требуют проверки экспорта или парсинга."],
               "Принять неполную массу как mix.", "Нормировка", "Проверка, что взаимоисключающие веса одного узла суммируются до единицы.", "30+50+10=90, поэтому данных не хватает.", "Суммируйте частоты только для одной руки и одного набора легальных детей узла.", "Точная проверка структуры экспорта; она не доказывает корректность strategy.", .exact,
               ["Raise", "30 %"], ["Call + fold", "60 %"], "nlhe-complete-knowledge-map.md#t51"),
        theory("E.foundation.t51.reproduce", .t51, "Воспроизводимое изменение", .transfer,
               ["Baseline содержит board Q♠7♦2♣, CO/BTN, stack100, pot6, rake5 %, ranges, sizes, tree, точность и версию программы.", "В копии изменён только rake с 5 % на 0 %; все остальные поля сохранены."],
               "Что описывает разницу результатов?", .choice(options: ["Sensitivity rake в указанной паре моделей", "Доказательство результата для всех столов", "Изменение ranges и rake"], correct: 0),
               ["Паспорт копии совпадает с baseline кроме одного входа.", "Разница относится к изменению rake в этой модели."],
               "Назвать sensitivity test доказательством поведения реальных игроков.", "Воспроизводимость", "Возможность собрать тот же результат из сохранённых версии, входов и процедуры.", "Две версии одного паспорта различаются только rake.", "Храните baseline, копию и список изменённых полей.", "Условная модель; лицензия и доступность внешнего инструмента могут ограничить повторный запуск.", .conditionalModel,
               ["Baseline", "rake 5 %"], ["Копия", "rake 0 %"], "nlhe-complete-knowledge-map.md#t51"),
        theory("E.foundation.t51.quality-boundary", .t51, "Граница корректного отчёта", .boundary,
               ["В архиве есть изображение частот, но нет исходных ranges, дерева, версии, rake, точности или файла экспорта."],
               "Какой статус у изображения?", .choice(options: ["Проверенная таблица", "Иллюстрация без воспроизводимого паспорта", "Основание для универсального exploit"], correct: 1),
               ["Изображение позволяет увидеть утверждение, но не восстановить модель.", "Нужны исходные входы и способ проверки."],
               "Подменить проверенную таблицу картинкой без входов.", "Проверенная таблица", "Таблица с разрешённым источником, полным паспортом, версией и процедурой проверки.", "Screenshot частот без ranges остаётся иллюстрацией.", "Маркируйте статус источника и отделяйте иллюстрацию от воспроизводимого результата.", "Понятийная задача. Учебный каталог не хранит внешние solver-файлы или лицензированные таблицы.", .definitions,
               ["Снимок", "частоты"], ["Статус", "иллюстрация"], "nlhe-complete-knowledge-map.md#t51")
    ]

    private static func theory(_ id: String, _ topic: CourseTopicID, _ title: String, _ purpose: FoundationPurpose,
                               _ context: [String], _ question: String, _ answer: FoundationAnswer, _ explanation: [String],
                               _ error: String, _ term: String, _ definition: String, _ example: String, _ method: String,
                               _ assumptions: String, _ kind: LessonResultKind, _ first: [String], _ second: [String], _ anchor: String) -> FoundationExercise {
        FoundationExercise(id: id, topicID: topic, title: title, purpose: purpose, context: context, question: question,
                           answer: answer, explanation: explanation, typicalError: error, term: term, definition: definition,
                           example: example, method: method, assumptions: assumptions, resultKind: kind,
                           diagram: [.init(first[0], first[1]), .init(second[0], second[1])], researchAnchor: anchor)
    }
}
