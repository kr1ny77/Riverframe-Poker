import Foundation

/// Review lessons use only the decision-time record. A later showdown may
/// explain the result, but cannot be used to change the original inputs.
public enum CourseReviewMath {
    public static func callEV(equity: Double, finalPot: Double, call: Double) -> Double? {
        guard equity.isFinite, finalPot.isFinite, call.isFinite, (0...1).contains(equity), finalPot >= call, call >= 0 else { return nil }
        let value = equity * finalPot - call
        return value.isFinite ? value : nil
    }

    public static func winRatePercent(wins: Double, observations: Double) -> Double? {
        guard wins.isFinite, observations.isFinite, wins >= 0, observations >= 1, wins <= observations, wins.rounded() == wins, observations.rounded() == observations else { return nil }
        return wins / observations * 100
    }
}

public extension FoundationLesson {
    private static func review(_ id: String, _ topic: CourseTopicID, _ title: String, _ purpose: FoundationPurpose,
                               _ context: [String], _ question: String, _ answer: FoundationAnswer,
                               _ explanation: [String], _ error: String, _ term: String, _ definition: String,
                               _ example: String, _ method: String, _ assumptions: String,
                               _ kind: LessonResultKind = .definitions, _ diagram: [FoundationDiagramRow]) -> FoundationExercise {
        .init(id: id, topicID: topic, title: title, purpose: purpose, context: context, question: question,
              answer: answer, explanation: explanation, typicalError: error, term: term, definition: definition,
              example: example, method: method, assumptions: assumptions, resultKind: kind, diagram: diagram,
              researchAnchor: "nlhe-complete-knowledge-map.md#\(topic.rawValue.lowercased())")
    }

    static let reviewExercises: [FoundationExercise] = [
        // MARK: T48 — satellite ICM
        review("E.foundation.t48.ticket-fold", .t48, "Сателлит: ценность фолда", .concept,
               ["Учебный satellite S0: A=50, B=30, C=20 chips; payouts: 1 ticket, 1 ticket, 0. Blinds 0,5/1, ante 0, rake 0.", "До решения B в SB: A BTN фолдит, B completes, C checks. Банк 2; stacks A/B/C=50/29/19.", "Flop и turn оба игрока check. River: B check, C all-in 19, B fold; непокрытая ставка возвращается C. Итоговые stacks 50/29/21. ICM применяет все три стека и одинаковые tickets."],
               "Введите ICM ценность B после фолда с точностью до 0,0001.", .number(value: try! CourseICM.prizeEquities(stacks: [50, 29, 21], payouts: [1, 1, 0])[1], tolerance: 0.0001),
               ["B получает ticket при первом или втором месте.", "ICM перечисляет порядок выбывания из вектора 50/29/21.", "Ценность B равна 0,6570886 ticket; единица результата — ticket, не chips."],
               "Сложить два ticket без вероятностей мест.", "Сателлитная структура", "Payout ladder, где несколько мест дают одинаковую награду.", "В S0 первое и второе места дают по одному ticket.", "Запишите все стеки и payouts, затем вычислите вероятность каждого оплачиваемого места.", "Условная ICM-модель без будущих уровней, skill и разделения tickets; арифметика точна внутри заданного дерева.", .conditionalModel,
               [.init("Stacks", "50 / 29 / 21"), .init("Tickets", "1 / 1 / 0"), .init("B fold", "0,6570886")]),
        review("E.foundation.t48.ticket-call", .t48, "Сателлит: call с заданными листьями", .transfer,
               ["S0: A BTN уже fold, B SB и C BB check на flop и turn. До river A/B/C=50/29/19, банк 2. B check, C ставит 19 all-in, B покрывает 19; B=AsQc, board Qd7c4h2s9d.", "Диапазон C: JcTc с вероятностью q и QhQs с вероятностью 1−q. После call весь банк 40: win stacks 50/50/0, lose 50/10/40.", "Payouts 1/1/0. При q=70 % ICM B: Uwin=1, Ulose=0,2666667; fold=0,6570886."],
               "Введите ICM EV call при q=70 % с точностью до 0,0001.", .number(value: try! CourseICM.weightedPrizeEV(probabilities: [0.7, 0.3], prizes: [1, 0.26666666666666666]), tolerance: 0.0001),
               ["Знаменатель вероятностей: 0,7+0,3=1.", "0,7×1 + 0,3×0,2666667 = 0,78.", "0,78 выше fold 0,6570886 в этой модели."],
               "Сравнить 70 % с числом chips B вместо ticket EV.", "ICM leaf", "Полный вектор стеков после отдельного исхода.", "Выигрыш S0 даёт B 50 chips, проигрыш — 10.", "Сначала вычислите ticket EV каждого leaf, затем умножьте на заданные вероятности.", "Условная модель: диапазон C и q заданы; решение игрока не выводится из реального поля.", .conditionalModel,
               [.init("Win 70 %", "0,7 × 1"), .init("Lose 30 %", "0,3 × 0,2666667"), .init("Call", "0,78 ticket")]),
        review("E.foundation.t48.ticket-boundary", .t48, "Сателлит: новая лестница выплат", .boundary,
               ["S0 сохраняет stacks и раздачу, но выплаты становятся 1 ticket / 1 ticket / 0,5 ticket.", "Предыдущие Ufold, Uwin и Ulose рассчитаны для payouts 1/1/0; новая лестница равна 0,5+0,5×старой для каждого места."],
               "Какой шаг корректен?", .choice(options: ["Перенести прежние ticket EV без пересчёта", "Пересчитать все ICM leaves с новым payout vector", "Считать, что третий стек уже не важен"], correct: 1),
               ["Выплаты входят в ценность каждого места.", "Новая награда третьему месту меняет Ufold, Uwin и Ulose.", "После пересчёта этого конкретного аффинного преобразования знак сравнения и порог остаются теми же; другое payout-изменение может их сдвинуть."],
               "Перенести число из другой payout structure.", "Паспорт модели", "Список стеков, payouts, правил и листьев, нужных для воспроизведения расчёта.", "Смена 0 на 0,5 ticket меняет паспорт S0.", "При любом изменении stacks или payouts пересчитайте leaves до сравнения и проверьте, является ли изменение аффинным.", "ICM остаётся учебной моделью и не оценивает будущую динамику стола.", .conditionalModel,
               [.init("Старые payouts", "1 / 1 / 0"), .init("Новые payouts", "1 / 1 / 0,5"), .init("Действие", "пересчитать leaves")]),

        // MARK: T52 — hand reconstruction
        review("E.foundation.t52.decision-record", .t52, "Разбор до вскрытия", .concept,
               ["NLHE cash 6-max: stacks по 100 bb, SB=0,5, BB=1, rake 0. BTN open 2,5, SB folds, BB calls: pot 5,5 bb.", "Flop Qd7c4h: BB checks, BTN checks. Turn 2s: BB checks, BTN checks. River 9d: BB checks, BTN bets 11 в pot 5,5.", "Hero BB знает AsQc, board, линию, pot 16,5 и call 11. Карты BTN неизвестны до action; после вскрытия BTN показал QhQs."],
               "Что должно войти в запись решения BB на river?", .choice(options: ["Только итог вскрытия", "Карты Hero, board, линия, pot, цена и диапазонная гипотеза до action", "Только эмоция после результата"], correct: 1),
               ["Качество решения оценивают из доступной информации в момент action.", "Showdown можно записать отдельным полем для проверки гипотезы.", "После просмотра QhQs нельзя подменять исходный диапазон BTN готовым знанием."],
               "Реконструировать диапазон так, будто карты BTN были известны заранее.", "Decision-time record", "Факты и гипотезы, доступные до конкретного действия.", "На river известны 16,5 bb, цена 11 и пять открытых карт.", "Сначала зафиксируйте улицу, pot, цену, cards, line и range; потом оцените EV и лишь затем сверяйте showdown.", "Процессная рамка; она не доказывает, что диапазонная гипотеза была верной.", .definitions,
               [.init("Известно", "AsQc; Qd7c4h2s9d; pot 16,5; call 11"), .init("Неизвестно", "карты BTN"), .init("Позже", "showdown отдельно")]),
        review("E.foundation.t52.counterfactual-ev", .t52, "Контрфактический call", .transfer,
               ["NLHE cash 6-max: stacks 100 bb, SB=0,5, BB=1, rake 0. BTN opens 2,5, SB folds, BB calls: pot 5,5. Flop: BB checks, BTN bets 7,25, BB calls; pot 20. Turn checks through.", "River: Hero BB checks, BTN bets 11, Hero решает call 11 или fold. Условная range-модель до action даёт equity q=25 % против линии BTN; final pot после call=42."],
               "Введите EV call в bb.", .number(value:  -0.5, tolerance: 0.0001),
               ["EV call = q×final pot − call.", "0,25×42 − 11 = −0,5 bb.", "Это ответ условной модели; проигрыш или выигрыш конкретного runout его не заменяет."],
               "Вычесть ставку BTN дважды или подменить диапазон картами последующего вскрытия.", "Контрфактическая линия", "Явно заданная альтернатива с теми же входами на момент решения.", "Для call сравнивают q×42 и цену 11.", "Зафиксируйте pot до call, final pot, цену и диапазонную equity; подпишите исключённые будущие эффекты.", "Условная модель с q=25 %; q требует отдельной проверки и может меняться с ranges и рейком.", .conditionalModel,
               [.init("Выигрыш", "25 % × 42 = 10,5"), .init("Цена", "11"), .init("EV call", "−0,5 bb")]),
        review("E.foundation.t52.missing-range", .t52, "Граница EV разбора", .boundary,
               ["River: pot before call=31 bb, Hero call=11 bb. Карты Hero и полный board записаны, диапазон соперника и equity отсутствуют.", "Результат вскрытия известен только после выбора action."],
               "Как записать вывод EV?", .choice(options: ["EV call точен по одной вскрытой руке", "EV неизвестен; сначала задать range и сценарии", "Победа в раздаче доказывает +EV"], correct: 1),
               ["Одна показанная рука описывает outcome, а не распределение скрытых рук до решения.", "Без range отсутствует q — вход формулы EV.", "Полезная запись отделяет неизвестный вход от итогового результата."],
               "Оценить весь диапазон одной рукой соперника.", "Граница модели", "Место, где вычисление прекращается из-за отсутствующего входа.", "Без q нельзя вычислить q×final pot−call.", "Пометьте EV неизвестным, соберите линию и предложите диапазонные сценарии вместо числа.", "Это ограничение данных, а не оценка качества игрока.", .definitions,
               [.init("Есть", "pot 31; call 11"), .init("Нет", "range / q"), .init("Вывод", "EV неизвестен")]),

        // MARK: T53 — errors and notes
        review("E.foundation.t53.price-error", .t53, "Ошибка цены колла", .concept,
               ["River: pot 80 bb, Villain bets 40 bb, Hero может fold или call 40. Final pot после call=160 bb.", "В заметке Hero записал «нужно 25 % equity»."],
               "Введите точный порог equity в процентах.", .number(value: 25, tolerance: 0.0001),
               ["Цена / final pot = 40/160.", "40/160=25 %.", "Запись верна только при нулевом рейке и без будущих улиц."],
               "Делить цену на pot до ставки: 40/80.", "Ошибка расчёта", "Неверный арифметический вход или действие с корректно известными данными.", "40/160 и 40/80 дают разные пороги.", "Сохраните pot, bet, call, final pot и формулу; это позволяет проверить ошибку отдельно от range.", "Точная арифметика указанных входов; реальный рейк меняет цену.", .exact,
               [.init("Pot до ставки", "80"), .init("Call", "40"), .init("Знаменатель", "160"), .init("Порог", "25 %")]),
        review("E.foundation.t53.model-error", .t53, "Ошибка диапазонной модели", .transfer,
               ["Hero верно посчитал river price 25 %. В заметке диапазон Villain содержит A♠A♦, хотя Hero держит A♠A♥.", "A♠A♦ физически невозможна; A♦A♣ остаётся допустимой. Математика цены корректна, но список комбинаций нарушает card removal."],
               "Какой тег ошибки уместен?", .choice(options: ["Расчёт", "Модель / диапазон", "Исполнение"], correct: 1),
               ["Цена колла не содержит ошибку.", "Конкретная A♠A♦ невозможна из-за A♠ у Hero, тогда как A♦A♣ допустима.", "Ошибка находится в предположении о диапазоне и влияет на q."],
               "Пометить это как расчёт из-за неверного итогового решения.", "Ошибка модели", "Неподходящий range, допущение или связь между входами.", "Card removal меняет допустимые комбинации диапазона.", "Проверяйте физические карты и допущения отдельно от формул и фактического клика.", "Классификация заметки не измеряет навык и не заменяет независимую проверку range.", .definitions,
               [.init("Формула", "верна"), .init("Range", "A♠A♦ невозможна"), .init("Тег", "модель")]),
        review("E.foundation.t53.execution-error", .t53, "Ошибка исполнения", .boundary,
               ["Арифметика и диапазонная модель до river указывают на call. Hero по ошибке нажал fold до проверки.", "Showdown позже показывает блеф, но выбор тега должен опираться на факты решения."],
               "Какой тег ошибки уместен?", .choice(options: ["Расчёт", "Модель / диапазон", "Исполнение"], correct: 2),
               ["Математическая модель и план были верны.", "Отклонение произошло между планом и выполненным action.", "Showdown может усилить эмоцию, но не меняет тип ошибки."],
               "Назвать любой проигрыш ошибкой модели.", "Ошибка исполнения", "Расхождение между выбранным планом и реально совершённым действием.", "Верный call-plan и фактический fold — execution case.", "Храните planned action и actual action рядом с расчётом.", "Один эпизод служит заметкой для ретеста, а не стабильным профилем игрока.", .definitions,
               [.init("План", "call"), .init("Факт", "fold"), .init("Тег", "исполнение")]),

        // MARK: T54 — deliberate practice
        review("E.foundation.t54.transfer-card", .t54, "Ретест с новыми входами", .concept,
               ["После ошибки price 40/160=25 % приложение предлагает три карточки: A повторяет 40/160; B использует 30/150; C спрашивает implied odds на flop.", "Цель ретеста — проверить тот же навык pot odds на новых числах."],
               "Какую карточку выбрать для ближайшего ретеста?", .choice(options: ["A", "B", "C"], correct: 1),
               ["B сохраняет правило price/final pot и меняет числа и ответ: 30/150=20 %.", "A преимущественно проверяет память ответа.", "C относится к другой модели с будущими ставками."],
               "Считать любую новую карточку одинаковым ретестом.", "Перенос", "Проверка того же правила при изменённых нерелевантных входах.", "30/150=20 % проверяет ту же формулу с другим знаменателем и ответом.", "Сначала назовите навык, затем измените числа или карты, оставив формулу и допущения явными.", "Учебная гипотеза; выбор карточки не подтверждает долгосрочное умение.", .definitions,
               [.init("Навык", "pot odds"), .init("A", "та же память"), .init("B", "новые числа, та же формула")]),
        review("E.foundation.t54.spacing-plan", .t54, "Интервал и цель ретеста", .transfer,
               ["Ученик правильно решил три разные карточки pot odds. План: сегодня 1 карточка, через 2 дня 1 карточка с новыми числами, через 14 дней 1 карточка с другой позицией.", "Интервалы и retention goal указаны явно; приложение не выводит профессиональный уровень из трёх ответов."],
               "Какое описание плана корректно?", .choice(options: ["Три повтора подряд дают такой же тест переноса", "Интервалы и меняющиеся входы поддерживают проверку удержания и переноса", "План доказывает устойчивый skill profile"], correct: 1),
               ["План разделяет попытки во времени и меняет часть входов.", "Он проверяет конкретные задания, а не гарантирует силу игры.", "Наблюдения остаются малой учебной выборкой."],
               "Вывести рейтинг навыка из малого числа ответов.", "Интервальное повторение", "Разнесённые попытки с заданной целью удержания.", "2 и 14 дней — явные интервалы плана.", "Запишите цель, дату следующей попытки, навык и изменённые входы; храните результат каждой попытки.", "Процессная модель, опирающаяся на исследования распределённой практики; оптимальный интервал зависит от retention interval и материала.", .definitions,
               [.init("Сегодня", "карточка 1"), .init("+2 дня", "новые числа"), .init("+14 дней", "другая позиция")]),
        review("E.foundation.t54.boundary-topic", .t54, "Граница одного ретеста", .boundary,
               ["Ученик ошибся в pot odds. Предложена новая карточка flop: нужно оценить implied odds, будущую ставку и вероятность получить оплату.", "Текущая карточка pot odds не содержит будущих улиц."],
               "Как пометить новую карточку?", .choice(options: ["Тот же ретест pot odds", "Отдельная тема и transfer-задача", "Доказательство, что pot odds усвоены"], correct: 1),
               ["Implied odds добавляют новые допущения о будущих действиях.", "Pot odds могут входить в расчёт, однако модель задачи шире.", "Правильная маркировка сохраняет понятную историю прогресса."],
               "Смешать разные модели в один счётчик mastery.", "Граница навыка", "Изменение, добавляющее новую формулу или допущение к проверяемому правилу.", "Будущая оплата отсутствует в чистом river pot-odds примере.", "Маркируйте transfer отдельно и перечисляйте добавленные входы до оценки ответа.", "Категоризация поддерживает обучение; она не измеряет причинный эффект расписания.", .definitions,
               [.init("Pot odds", "цена / final pot"), .init("Implied odds", "добавляет будущие деньги"), .init("Тег", "transfer")]),

        // MARK: T60 — capstone
        review("E.foundation.t60.audit-price", .t60, "Capstone: проверка цены", .concept,
               ["NLHE cash 6-max, river: pot 90 bb, BTN bets 30 bb, Hero может call 30. Рейк 0; дальнейших улиц нет.", "В заметке указан диапазонный equity q=25 % и отдельное поле «showdown неизвестен на момент action»."],
               "Введите EV call в bb.", .number(value: 7.5, tolerance: 0.0001),
               ["Final pot=90+30+30=150 bb.", "EV=0,25×150−30=37,5−30=7,5 bb.", "EV call=+7,5 bb при данном q."],
               "Использовать pot до ставки как final pot.", "Аудит ввода", "Проверка единиц, pot, цены, вероятности и допущений до вывода EV.", "30/150=20 % — порог; q=25 % выше порога.", "Восстановите pot, final pot, цену, q и EV; отделите известное до action от последующего showdown.", "Условная модель q=25 %, рейк 0 и одна улица; q требует проверки диапазона.", .conditionalModel,
               [.init("Final pot", "150 bb"), .init("q", "25 %"), .init("EV", "+7,5 bb")]),
        review("E.foundation.t60.audit-icm", .t60, "Capstone: смена единиц ICM", .transfer,
               ["MTT S0: stacks и payouts 1/1/0 ticket; B рассматривает call all-in. Все terminal stacks и диапазонная вероятность q отсутствуют из записи.", "Старая cash-formula q×final pot−call использует chips и не описывает ticket value."],
               "Что требуется перед рекомендацией?", .choice(options: ["Только pot odds из cash", "Все terminal stacks, payouts и вероятность исходов для ICM EV", "Только результат предыдущего showdown"], correct: 1),
               ["ICM EV строится из prize value leaves.", "Нужны stacks каждого игрока до и после ветвей, payouts и вероятности win/tie/lose.", "Cash chip EV можно показать параллельно, но он имеет другую единицу."],
               "Перенести cash-порог без payout tree.", "Смена метрики", "Переход от chip EV к prize EV при заданной турнирной структуре.", "Tickets 1/1/0 требуют ICM leaves, а не только pot odds.", "Соберите паспорт: field stacks, payouts, action, leaves и вероятности; затем сравните ICM call с ICM fold.", "Условная ICM-модель исключает skill edge, future play и нестандартные правила турнира.", .conditionalModel,
               [.init("Cash", "chips"), .init("Satellite", "tickets"), .init("Нужно", "leaves + payouts + q")]),
        review("E.foundation.t60.independent-review", .t60, "Capstone: независимая проверка", .boundary,
               ["Запись решения содержит cards, board, action, pot, цену, range, q, рейк и допущения. Reviewer проверил правила, арифметику и допустимость карт.", "Reviewer не имеет репрезентативной выборки поля и не подтверждает эксплуатационную гипотезу о привычке соперника."],
               "Какой вывод корректен?", .choice(options: ["Reviewer подтвердил универсальный exploit", "Reviewer подтвердил входы и расчёт; полевая гипотеза остаётся условной", "Showdown больше не нужен как отдельное поле"], correct: 1),
               ["Проверка может подтвердить воспроизводимость записанной модели.", "Данные поля требуют отдельной достаточной выборки и отбора.", "Качество исходного решения и результат вскрытия сохраняются раздельно."],
               "Назвать локальную проверку доказательством выгоды в поле.", "Независимая проверка", "Проверка правил, карт, арифметики и допущений другим читателем.", "Reviewer сверяет 30/150, q и отсутствие повторяющихся карт.", "Передайте полный паспорт решения; отмечайте, какие выводы проверены, а какие остаются гипотезами.", "Процессная рамка: reviewer не гарантирует прибыль и не заменяет реальные выборки.", .definitions,
               [.init("Проверено", "rules / cards / arithmetic"), .init("Условно", "field hypothesis"), .init("Outcome", "отдельно")])
    ]
}
