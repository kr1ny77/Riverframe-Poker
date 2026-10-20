# Спецификации SwiftUI-компонентов

> Спецификация первого этапа. Реализованный редизайн 18.10.2026 описан в [visual-direction.md](visual-direction.md) и [final-review.md](final-review.md); актуальная палитра находится в tokens.json.

Общие контракты: компоненты получают immutable публичные DTO и callbacks. Ввод живёт в draft до подтверждения. Единственный источник легальных действий/выплат — PokerCore через Application. Числа и текст не вычисляются из анимаций. Все размеры базовые в pt; Dynamic Type увеличивает текст и необходимый контейнер. Общие enabled/pressed/disabled/submitting/focused/error состояния описаны через токены foundations.md.

## C01 — AppButton

- Варианты: primary accent/on-accent, secondary surface/text + border-input, quiet accent на bg/surface, destructive danger/on-accent.
- Размер: minHeight 48, горизонтальный padding 16, вертикальный 12, radius md. Для вторичной иконки область 44×44.
- States: default; pressed accent-pressed/on-accent; focus 2-pt accent с 2-pt focus-separator вокруг акцентной кнопки; disabled surface-alt/text-muted с пояснением причины; submitting сохраняет label и показывает ProgressView; error — inline сообщение рядом.
- Accessibility: SwiftUI Button с label/hint; действие подтверждения по внешнему keyboard доступно; enabled не кодируется одной прозрачностью. После выполнения фокус переходит к результату.
- Используется: все экраны, ActionBar, Editor.

## C02 — PlayingCard / SuitShape / CardBack

- Вход: visibleRank/visibleSuit либо hidden/empty; sizeRole; selected/highlightedBestFive. Закрытый DTO не содержит реальные rank/suit.
- SwiftUI-контракт: Shape/Path для масти, RoundedRectangle для поверхности, Text для ранга; Rubashka — собственные параллельные диагональные линии в рамке. Масштаб в координатах 0…1, stroke пропорционален размеру.
- Варианты hero/board/review; ratio 5:7, угол 6. Ранг в верхнем левом углу с inset 4…6; масть в центре. На крупных картах можно повторить ранг снизу с поворотом. Все интерактивные карты имеют общую touch area ≥44×44.
- State: faceUp, hidden, futureSlot, selected (2-pt card-ink на лицевой карте, внешний table-accent halo на table), bestFive (галочка с текстовым итогом), unavailable (текст «Занята» в редакторе карт). Наличие карты, выбор и победа различаются формой/подписью.
- A11y: один элемент «Туз пик», «Десятка червей»; пустой/закрытый слот произносит только статус. Декоративные масти скрыты отдельно. HeroHand может озвучиваться группой «Ваши карты: …».
- Используется: S04/S05/S06/S09, выбор карт для equity.

## C03 — PlayerSeat / HeroHand / DealerButton

- Вход: seatID, displayName, position, stack, streetContribution, visibleCards, publicState, isButton, lastAction. Результат и банк приходят отдельными событиями.
- Базовая плашка соперника 86 pt целевой ширины, естественная высота от 64; точки компоновки задаёт TableLayout. В тесном месте переключается layout, текст стека не сжимается.
- States: waiting, acting, folded, allIn, winner, paused. Acting: контур table-accent 2 и подпись. Folded: «Пас». All-in: «Олл-ин» и стек 0. Winner: точная выплата. Никакого полного понижения opacity для считываемых сумм.
- DealerButton: badge D 22 pt декоративно, при открываемой справке hit area 44; a11y «Баттон у Бота 2». PositionBadge — отдельные BTN/SB/BB/UTG/HJ/CO и раскрытие терминов.
- A11y: group summary «Бот 2, большой блайнд, осталось 950, внёс 50, ходит»; раскрытие подробностей через Button. HeroHand имеет собственное понятное название.
- Используется: S04/S05/S09.

## C04 — TableLayout / BoardView

- Вход: список шести SeatSnapshot, BoardSnapshot, PotSnapshot; layoutMode compact/standard/linear. BoardView — HStack пяти карт с gap 6…8; конфигурация flop/turn/river оставляет будущие слоты.
- Поле table-bg, места table-surface, текст table-text/table-muted. Ориентиры геометрии в screens.md, финальное размещение измеряет собственный Layout. Системные safe areas учитываются извне.
- States: dealing, ready, awaitingHero, awaitingBot, runout, showdown, completed, paused. Неполная доска видима ровно до текущей улицы.
- A11y: отдельная линейная семантика, независимая от физического расположения. Порядок — контекст, банк, board, hero, очередь игроков, доступные действия.
- Используется: S04 и упрощённая схема S05/S09.

## C05 — PotSummary / StackLabel / StakeBadge / ChipGlyph

- Вход: chips Int64, displayUnit, текущие вклады, sidePot summaries и eligible labels. Форматирование централизовано.
- StackLabel: supporting semibold monospacedDigit, подпись «Осталось». PotSummary: heading; side pots — раскрываемая строка. StakeBadge: «Внёс 50», SB/BB всегда текстом.
- ChipGlyph: собственная SwiftUI Shape из окружности и коротких радиальных штрихов, масштаб 12…24 pt. Цвет не обозначает номинал. Декоративные стопки ограничены тремя значками независимо от величины суммы.
- State: normal, changing, settled, returned. Changing меняет число сразу по snapshot; returned имеет явную подпись. Большие суммы переносятся/открываются целиком, формат K/M для точных ставок исключён.
- A11y: «Банк: 150 учебных фишек; включает текущие ставки», «Вклад на улице: 50». Decorative chips hidden.
- Используется: S04/S05/S09.

## C06 — ActionBar

- Вход: legalActions, callAmount, minRaiseTo, maxRaiseTo, revision, submitting, explanationForUnavailable. Выход: немедленное действие или открытие Editor.
- Минимальные строки: fold/call и raise; check/bet в бесплатном ходе. Text labels + суммы, минимум 48 высоты и 8 spacing. Ни одно действие не определяется только пиктограммой.
- State: heroTurn, botTurn (статус «Ход Бота …»), committing, stale, paused, settlement. На botTurn action buttons заменены спокойной строкой, без движущегося таймера. Disabled reason доступна в справке.
- A11y: labels «Колл, добавить 50»; фокус не прыгает между ботами; при heroTurn одно объявление «Ваш ход». Voice Control использует видимые названия.
- Используется: S04/S05; точные переходы в screens.md.

## C07 — BetSizeEditor / NumericField / PresetButton

- Вход: legal range и предложения от Application, банк, x, C, stack, revision. Выход: подтверждённый target Int64. Вычисление пресетов следует соглашению screens.md, окончательную легальность возвращает Core.
- Field: surface, text, border-input 1, focus accent 2, error danger 2 + описание. Текст body, сумма title. Редактор содержит min/max, добавляемую сумму, slider, точный ввод и основную кнопку.
- PresetButton: minHeight 44, две строки «½ банка» / «50». Selected: accent/on-accent; default surface/text+border-input. Выбранное состояние озвучивается.
- States: valid, invalidText, belowMin, aboveStack, onlyAllIn, singleValue, submitting, stale. Ошибка не изменяет автоматически введённую сумму. При отмене исходный стол цел.
- A11y: Slider с value в фишках и accessibilityAdjustableAction, рядом точный TextField и +/- Buttons; клавиатура числовая, toolbar «Готово». Enter может завершать ввод, окончательная отправка требует понятного confirm.
- Используется: S04/S05.

## C08 — TopicRow / FilterPicker / SessionSetup

- Вход: topic, краткая цель, verifiedItemCount, выбранные условия, hints. Выход: выбранный preset.
- TopicRow: text/heading + supporting, справа count и disclosure; собственная touch область всей строки. Темы содержат оригинальные словесные обозначения, без чужих иллюстраций.
- FilterPicker: системный Picker/Toggle, выбранный фильтр в заголовке набора. Пустой результат показывает «Сбросить фильтры». Не готовый модуль исключён из доступного каталога.
- States: available, selected, emptyResult, loadingCatalog, contentError.
- A11y: название/цель/count объединены, фильтр объявляет текущее значение; при reset фокус возвращается к списку.
- Используется: S02/S03/S08.

## C09 — ExercisePrompt / AnswerInput / HintDisclosure

- Вход: immutable ScenarioPrompt, index/total, доступный тип ответа и hints mode. Выход: один answer envelope.
- Карты/схема и вопрос сохраняются при review; контекст раскрывается по требованию. Для numeric показывается единица, например «Процент»; пустое значение не отправляется. Choice options min 48 pt.
- States: unanswered, selected, submitting, reviewed, interrupted. Hint даёт original explanation fragment и помечает hintsUsed.
- A11y: question heading, условия, визуальные карты в текстовом эквиваленте, ответ, check; hint доступен как disclosure Button.
- Используется: S05.

## C10 — AnswerFeedback / Explanation / MetricLine

- Вход: reviewStatus, userAnswer, keyAnswer, explanation, assumptions, formula, modelVersion. Цвет success/danger/warning/text дополняет icon+status.
- Без тяжёлой модальности: inline панель surface с ведущей линией 3 pt, body текст, «Подробный расчёт» для дополнительной глубины. Формула переносится по операторам и имеет текстовое представление.
- States: correct, incorrect, acceptableAlternative, ungraded. У ungraded отсутствует score; данные о методе/допуске не теряются. Error сохранения оставляет пользователя на том же вопросе с действием Retry.
- A11y: один объявляемый статус, затем доступный review. Фокус переходит на heading результата; «Дальше» остаётся отдельным действием.
- Используется: S06/S07, детали попытки.

## C11 — ProgressSummary / TopicMetric / Trend / SessionRow

- Вход: judgedAttempts, accuracy numerator/denominator, topic, hints/repeats filters, timestamps. Показывать число наблюдений рядом с процентом.
- TopicMetric — строка с темой, «7 из 10», bar с text alternative и «Практиковать». Trend использует axis labels, период и текстовые данные в списке; линия accent, точки с контуром и понятными подписями.
- States: empty, insufficientData, populated, filtering, historyUnavailable. «Нет данных» не превращается в 0%.
- A11y: числовой summary и доступные значения по сессиям. Никакого одиночного цветового графика в качестве единственного источника данных.
- Используется: S07/S08.

## C12 — HandTimeline / PotBreakdown / OutcomePanel

- Вход: только publicReviewData по текущему шагу, раскрытые карты, payouts/refunds/oddChips.
- Timeline: previous/next 44+, улицы текстом, последовательность действий списком. PotBreakdown: main/side суммы и eligible места. OutcomePanel: результат + точные выплаты + bestFive после вскрытия.
- States: firstStep, intermediate, final, uncontested, showdown, split, refunded, unavailable. На границах шага previous/next отключены семантически.
- A11y: номер шага, публичное действие, банк; скрытая информация закрыта и визуально, и в label. Итог разделения читается по банкам/игрокам.
- Используется: S09 и завершение S04.

## C13 — StatusPanel / ErrorNotice / EmptyState / LoadingIndicator

- Вход: краткий title, причина, доступные recovery actions и data scope. Каждая ошибка имеет одно основное действие.
- Empty: heading+body+CTA без декоративной картинки. Loading: ProgressView с label, процент только если известен. Error: danger текст/иконка на surface, body объяснение. Успех не зависит от toast, который может исчезнуть раньше чтения.
- States: loading, empty, inputError, storageError, recoverableSessionError, unrecoverableSessionError. Ввод сохраняется при исправимой ошибке. Background пауза не маркируется как ошибка.
- A11y: значимый статус объявляется один раз; фокус у основного recovery действия. Никаких бесконечных повторов звука/announcement.
- Используется: все разделы.

## C14 — SettingsGroup / DestructiveConfirmation / RootNavigation

- Вход: local settings snapshot, settings commands, typed routes. Используются системные Form/Section/Toggle/Picker/NavigationStack/TabView.
- Tab labels всегда видимы: Играть, Тренировка, Прогресс, Настройки. Primary tint accent; focus определяется системной доступностью. Строки имеют естественную высоту и достаточный отступ.
- Clear: alert с описанием удаляемого объёма и Cancel; действие Delete в danger. Успех очистки приводит к empty state, не закрывает приложение.
- States: default, changed, writing, failed, confirmClear, cleared. Изменение правил влияет на следующую руку по архитектуре.
- A11y: значения настроек и причины read-only проговариваются; hardware keyboard и Switch Control используют системные элементы.
- Используется: S01/S02/S10 и все tab roots.

## C15 — RangeMatrix / ComboRow

- Вход: 169 классов с частотами и доступными конкретными комбинациями, видимые blockers, выбранная рука, версия набора. Размер viewport определяется шириной экрана.
- Матрица — обзор: строки A…2, диагональ пары, один треугольник suited, второй offsuit с явной легендой. На узком iPhone cell около 22 pt; отдельное попадание в мелкую cell не является обязательным способом ввода. Рядом доступны фильтр по рангу и список ComboRow с hit area ≥44×44 для точного выбора. Sheet позволяет увеличить обзор.
- Частота показывается текстом и длиной полосы внутри cell; accent обозначает выбранный класс через контур. Значения цветов — text/accent на surface/surface-alt. Стратегические действия в mixed frequency дополнены аббревиатурами и доступными числами; множество дополнительных кодирующих цветов в V1 исключено.
- States: overview, selected, blocked, empty, sourceUnavailable. После блокеров показываются доступные комбинации и сумма весов. Отсутствующий набор не заменяется универсальной таблицей.
- A11y: линейный список «Туз-король одной масти, 4 доступных комбинации, вес …», кнопка подробностей; текущий selection объявляется. При accessibility text список становится основным видом.
- Используется: тема «Диапазоны», условия упражнения, калькулятор equity.

## Дополнение: контраст карт и служебных границ

Рубашка card-back на table-bg/table-surface получает сплошной белый внешний stroke 1 pt; её контур определяется проверенной парой card-face/table-bg либо table-surface. Лицевая карта получает card-ink border при необходимости; её белая поверхность контрастирует с тёмным экраном. Selected/bestFive на поверхности карты использует card-ink outline и текстовый label; на тёмном поле внешний halo использует table-accent. Служебный focus на table также table-accent. Акцентные labels на тёмном поле используют проверенный table-accent. Узор рубашки использует on-card-back.

## C16 — Выбор пятёрки в уроке комбинаций (реализованный срез)

- SwiftUI-компонент `HandComparisonLessonView` использует тёмные surface/bg, accent, success/warning и размеры из `AppTheme`.
- Карманные карты A и общая доска доступны для выбора; карты B служат контекстом. Выбор обозначают контур, checkmark и accessibilityValue. Счётчик показывает 0…5, проверка доступна при пяти выбранных картах.
- Размер карты масштабируется через ScaledMetric; адаптивная сетка переносит карты на следующие строки. Внутренние символы карты ограничены xxxLarge, при этом физический размер растёт с настройкой текста. VoiceOver получает полное название карты и состояние выбора. Отдельная жестовая приёмка VoiceOver остаётся в плане.
- Разбор содержит обе лучшие пятёрки, объяснение и действие продолжения; при ошибке записи — разбор и retry. Готовый ответ блокирует повторный ввод.
- Реальный кадр iPhone17e Simulator: [выбор пятёрки](../clone-screens/S-combinations-question.png). Проверки/ограничения: [приёмка урока](../tests/combinations-results.md).
