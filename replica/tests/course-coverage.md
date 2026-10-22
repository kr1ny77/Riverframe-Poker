# Покрытие каталога по исходникам

Редакция 4, 22 октября 2026. 43 legacy + 39 Foundation v2 + 50 v3 + 49 v4 = **181 уникальное упражнение**.
M01–M13: 45 тем с опубликованным учебным объёмом. M14–M18: 15 тем следующего этапа.
Статус «Блок доступен» описывает доступность материала. Охват и точность ответов измеряются отдельно.

## Модули M01–M18

| ID | Название | Темы | Уникальные задачи | Статус |
| --- | --- | --- | --- | --- |
| M01 | Правила и банки | T01, T02, T03, T04, T05 | 38 | Блоки тем доступны |
| M02 | Колода и события | T06, T07 | 11 | Блоки тем доступны |
| M03 | Equity и цена решения | T08, T09, T11 | 17 | Блоки тем доступны |
| M04 | Стартовые руки и позиции | T21, T22, T28 | 13 | Блоки тем доступны |
| M05 | Точность оценок | T10, T16 | 6 | Блоки тем доступны |
| M06 | Будущая стоимость и рейк | T14, T15 | 6 | Блоки тем доступны |
| M07 | Префлоп-линии | T23, T24, T25, T26, T27 | 15 | Блоки тем доступны |
| M08 | Условные диапазоны | T17, T18, T32 | 13 | Блоки тем доступны |
| M09 | Основы постфлопа | T29, T34, T35, T37, T39 | 17 | Блоки тем доступны |
| M10 | Агрессия и план улиц | T12, T13, T36, T38 | 13 | Блоки тем доступны |
| M11 | Распределения и multiway | T30, T31, T33, T40 | 13 | Блоки тем доступны |
| M12 | Частоты и bluff-catching | T19, T20 | 6 | Блоки тем доступны |
| M13 | Стоимость турнирного стека | T45, T46, T47, T49, T50 | 17 | Блоки тем доступны |
| M14 | Теория и солверы | T41, T42, T43, T51 | 0 | Подготовка |
| M15 | Эксплойт и гипотезы | T44 | 0 | Подготовка |
| M16 | Сателлиты | T48 | 0 | Подготовка |
| M17 | Разбор и повторение | T52, T53, T54, T60 | 0 | Подготовка |
| M18 | Риск и процесс | T55, T56, T57, T58, T59 | 0 | Подготовка |

Сумма по модулям учитывает совместные E-ID; общий охват использует множество из 181 ID.
T11 переиспользует pot odds и EV-call; T02/T21 разделяют урок позиций; T06/T18 разделяют блокеры.
T32 сохраняет единственный материал linear/polarized/capped/uncapped; T30/T33 используют его как предпосылку.

## Темы T01–T60

| ID | Название | Модуль | Статус | Прежние / Foundation | Недостающее и проверки |
| --- | --- | --- | --- | --- | --- |
| T01 | Лучшая пятёрка, kicker, ничья и wheel | M01 | Блок доступен | 12 / 0 | Расширение сценариев и ручная проверка интерфейса; Прежние unit/Application/UI проверки |
| T02 | Позиции и порядок действий | M01 | Блок доступен | 9 / 0 | Расширение сценариев и ручная проверка интерфейса; Прежние unit/Application/UI проверки |
| T03 | Блайнды, анте, эффективный стек и SPR | M01 | Блок доступен | 0 / 6 | Расширение сценариев и ручная проверка интерфейса; FoundationRulesTests / FoundationArchiveTests / AppChecks / UI T03 |
| T04 | Легальные действия, min-raise и неполный all-in | M01 | Блок доступен | 0 / 6 | Расширение сценариев и ручная проверка интерфейса; FoundationRulesTests / FoundationArchiveTests / AppChecks / UI T04 |
| T05 | Side pots, odd chips и возврат лишней ставки | M01 | Блок доступен | 0 / 5 | Расширение сценариев и ручная проверка интерфейса; FoundationRulesTests / FoundationArchiveTests / AppChecks / UI T05 |
| T06 | Комбинации и события без возвращения | M02 | Блок доступен | 3 / 3 | Расширение сценариев и ручная проверка интерфейса; FoundationRemainingTests / FoundationArchiveTests / AppChecks / UI T06 |
| T07 | Точные outs и dirty outs | M02 | Блок доступен | 2 / 3 | Расширение сценариев и ручная проверка интерфейса; FoundationRemainingTests / FoundationArchiveTests / AppChecks / UI T07 |
| T08 | Точная equity против известной руки | M03 | Блок доступен | 2 / 3 | Расширение сценариев и ручная проверка интерфейса; FoundationRemainingTests / FoundationArchiveTests / AppChecks / UI T08 |
| T09 | Equity против взвешенного диапазона | M03 | Блок доступен | 3 / 3 | Расширение сценариев и ручная проверка интерфейса; FoundationRemainingTests / FoundationArchiveTests / AppChecks / UI T09 |
| T10 | Monte Carlo, дисперсия оценщика и ошибка | M05 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseEstimationTests; UI маршрут/ответ/relaunch |
| T11 | Pot odds и EV call/fold | M03 | Блок доступен | 6 / 0 | Расширение сценариев и ручная проверка интерфейса; Прежние unit/Application/UI проверки |
| T12 | Bet EV, fold equity и чистый блеф | M10 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseAggressionTests; UI маршрут/ответ/relaunch |
| T13 | Raise, reshove и all-in EV | M10 | Блок доступен | 0 / 4 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseAggressionTests; UI маршрут/ответ/relaunch |
| T14 | Implied odds, reverse implied odds и доминирование | M06 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseEstimationTests; UI маршрут/ответ/relaunch |
| T15 | Rake и cap | M06 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseEstimationTests; UI маршрут/ответ/relaunch |
| T16 | Variance, размер выборки и интервал | M05 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseEstimationTests; UI маршрут/ответ/relaunch |
| T17 | Байесовское обновление диапазона и предположения о блефе | M08 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseRangesPostflopTests; BlockerLessonTests; UI маршрут/ответ/relaunch |
| T18 | Blockers и removal effects | M08 | Блок доступен | 6 / 0 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseRangesPostflopTests; BlockerLessonTests; прежний маршрут BlockerLessonView |
| T19 | MDF и bluff:value в toy river game | M12 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseAggressionTests; UI маршрут/ответ/relaunch |
| T20 | Bluff-catcher и порог колла | M12 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseAggressionTests; UI маршрут/ответ/relaunch |
| T21 | Свойства стартовых рук и доминирование | M04 | Блок доступен | 3 / 3 | Расширение сценариев и ручная проверка интерфейса; FoundationRemainingTests / FoundationArchiveTests / AppChecks / UI T21 |
| T22 | Open-raise и чарты по позиции | M04 | Блок доступен | 1 / 4 | Расширение сценариев и ручная проверка интерфейса; FoundationRemainingTests / FoundationArchiveTests / AppChecks / UI T22 |
| T23 | Защита BB | M07 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CoursePreflopTests; UI маршрут/ответ/relaunch |
| T24 | Limp, isolation и dead money | M07 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CoursePreflopTests; UI маршрут/ответ/relaunch |
| T25 | 3-bet, 4-bet и 5-bet | M07 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CoursePreflopTests; UI маршрут/ответ/relaunch |
| T26 | Cold call и squeeze | M07 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CoursePreflopTests; UI маршрут/ответ/relaunch |
| T27 | Короткий стек: shove и resteal | M07 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CoursePreflopTests; UI маршрут/ответ/relaunch |
| T28 | Heads-up, 6-max и full ring | M04 | Блок доступен | 0 / 3 | Расширение сценариев и ручная проверка интерфейса; FoundationRemainingTests / FoundationArchiveTests / AppChecks / UI T28 |
| T29 | Текстуры доски | M09 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseRangesPostflopTests; UI маршрут/ответ/relaunch |
| T30 | Range advantage и nut advantage | M11 | Блок доступен | 0 / 4 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseDistributionsTests; UI маршрут/ответ/relaunch |
| T31 | Реализация equity и playability | M11 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseDistributionsTests; UI маршрут/ответ/relaunch |
| T32 | Linear, polarized, capped и uncapped | M08 | Блок доступен | 0 / 4 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseRangesPostflopTests; BlockerLessonTests; UI маршрут/ответ/relaunch |
| T33 | Board coverage | M11 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseDistributionsTests; UI маршрут/ответ/relaunch |
| T34 | C-bet и delayed c-bet | M09 | Блок доступен | 0 / 4 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseRangesPostflopTests; UI маршрут/ответ/relaunch |
| T35 | Probe bet и donk bet | M09 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseRangesPostflopTests; UI маршрут/ответ/relaunch |
| T36 | Check-raise | M10 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseAggressionTests; UI маршрут/ответ/relaunch |
| T37 | Value, protection и semi-bluff | M09 | Блок доступен | 0 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseRangesPostflopTests; UI маршрут/ответ/relaunch |
| T38 | Сайзинг, overbet, SPR и план улиц | M10 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseAggressionTests; UI маршрут/ответ/relaunch |
| T39 | IP и OOP | M09 | Блок доступен | 1 / 3 | Расширение сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseIntermediateTests: baseline82 + roundtrip132; CourseRangesPostflopTests; UI маршрут/ответ/relaunch |
| T40 | Multiway pots | M11 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseDistributionsTests; UI маршрут/ответ/relaunch |
| T41 | Равновесие, GTO и предел exploitability | M14 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T42 | Чувствительность solver-отчёта к входам | M14 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T43 | Смешанные действия и допустимое упрощение | M14 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T44 | Эксплойт, nodelock и малые выборки | M15 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T45 | ICM и chip EV | M13 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseICMTests + независимый Fraction oracle; UI маршрут/ответ/relaunch |
| T46 | Risk premium и bubble factor | M13 | Блок доступен | 0 / 4 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseICMTests + независимый Fraction oracle; UI маршрут/ответ/relaunch |
| T47 | Баббл, поздняя стадия MTT и pay jumps | M13 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseICMTests + независимый Fraction oracle; UI маршрут/ответ/relaunch |
| T48 | Satellite ICM | M16 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T49 | Короткий стек, анте, push/fold и reshove | M13 | Блок доступен | 0 / 3 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseICMTests + независимый Fraction oracle; UI маршрут/ответ/relaunch |
| T50 | Multiway all-in, side pots и ICM | M13 | Блок доступен | 0 / 4 | Расширение условных сценариев; ручная VoiceOver/адаптивная приёмка отложена; CourseAdvancedTests: baseline132 + roundtrip181; CourseICMTests + независимый Fraction oracle; UI маршрут/ответ/relaunch |
| T51 | Воспроизводимость и валидация solver-модели | M14 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T52 | Разбор раздачи и контрфактические линии | M17 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T53 | Таксономия ошибок и заметки | M17 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T54 | Целенаправленная практика, интервалы и ретест | M17 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T55 | Тильт, усталость и внимание | M18 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T56 | Банкролл, риск и дисперсия | M18 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T57 | Выбор игры и неопределённость поля | M18 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T58 | Live tells, надёжность и обновление Байеса | M18 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T59 | Ответственная игра: лимиты и признаки риска | M18 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |
| T60 | Capstone: полный аудит решения и независимая проверка | M17 | Подготовка | 0 / 0 | Объяснения, сценарии, типизированные ответы, интерфейс; Задачи, независимые ключи, UI и persistence предстоят |

## Экраны и вычислители

CourseCatalogView → CourseModuleView → CourseTopicView → FoundationLessonView: цель, ситуация,
рамки «Термин»/«Метод», ответ, разбор, следующая задача и восстановленный результат.
CourseAggressionMath вычисляет EV ветвей, MDF, B/V и B/(B+V) с отдельными знаменателями.
CourseDistributionMath вычисляет массы, условную EQR и совместные исходы; T32 переиспользуется.
CourseICM перечисляет места для 2–6 игроков; схема архива остаётся 6.
FoundationDecisionTree показывает подписанные ветви/расчёт с текстовой альтернативой для VoiceOver.
Турнирные сценарии доступны в обучении; игровой стол сохраняет 6-max cash-practice.

[Манифест](evidence/advanced-v4/catalog-manifest.json) получен из скомпилированного PokerCore командой `./Tools/export-course-catalog.sh`.
[CSV](course-coverage.csv) содержит все E-ID. [Приёмка этапа](advanced-results.md).
