# ADV — M10–M13, редакция 4

| ID | Критерий | Проверка |
| --- | --- | --- |
| ADV-01 | 49 новых ID; три цели каждого из 15 T-ID; всего181 | CourseAdvancedTests |
| ADV-02 | Fold/call/raise/all-in EV; покрытие стеков; размеры | CourseAggressionTests |
| ADV-03 | MDF, B/V и B/(B+V) имеют свои знаменатели | CourseAggressionTests + CourseAdvancedTests |
| ADV-04 | Физические ranges, nut-class, board coverage, EQR>100%, joint outcomes | CourseDistributionsTests + независимое перечисление пар |
| ADV-05 | R0/R1/tie, все конечные стеки, выплаты, chip/prize EV, BF/risk premium | CourseICMTests + Fraction oracle |
| ADV-06 | Поле2–6, один/несколько нулевых стеков, симметрия, WTA, одинаковые выплаты, крайние числа | CourseICMTests + CourseAdvancedTests |
| ADV-07 | Все132 прежние записи +49 новых, UUID/даты/оценки/completion8/8 | baseline a77cc08 fixture + roundtrip181 |
| ADV-08 | Все15 тем: экран/проверка/сохранение/перезапуск | testAdvancedTopicsAndRelaunch |
| ADV-09 | ICM tie, числовой порог/risk premium, ICM после side pot | testAdvancedICMLeavesAndThresholds |

Команды: `swift test -c release`, `./Tools/verify.sh`,
`./Tools/test-course-ios.sh testAdvancedTopicsAndRelaunch`,
`./Tools/test-course-ios.sh testAdvancedICMLeavesAndThresholds`.
Независимый oracle: `python3 Tools/check-advanced-course.py` (stdlib Fraction и перестановки).
XXXL и расширенная ручная доступность отложены пользователем.

Ниже — планы предыдущих этапов.

# INT — M05–M09, редакция 3

| ID | Критерий | Проверка |
| --- | --- | --- |
| INT-01 | 50 новых ID, три цели на каждый новый T-ID, 132 общих | CourseIntermediateTests |
| INT-02 | Замороженный MC seed/N/W/T/L, ties, SE и 95% | CourseEstimationTests + CourseIntermediateTests |
| INT-03 | Implied/reverse, rake/cap, единицы, независимые ключи | CourseEstimationTests + CourseIntermediateTests |
| INT-04 | Префлоп: полный банк/вклад, короткий стек, условный паспорт | CoursePreflopTests |
| INT-05 | Байес/веса, физические карты, linear/polar/cap, позиция и типы ставок | CourseRangesPostflopTests |
| INT-06 | Все 82 старых результата + 50 новых после записи/reload; completion 8/8 | fixture baseline67e44b4 + CourseIntermediateTests |
| INT-07 | Все 16 дополненных T-ID: маршрут, ответ, сохранение, relaunch | testIntermediateTopicsAndRelaunch |
| INT-08 | MC отчёт и ввод с запятой; округление Байеса и восстановление | testMonteCarloReportAndBayesRounding |

Команды: `swift test -c release`, `./Tools/verify.sh`,
`./Tools/test-course-ios.sh testIntermediateTopicsAndRelaunch`,
`./Tools/test-course-ios.sh testMonteCarloReportAndBayesRounding`.
XXXL и расширенная ручная доступность отложены пользователем.

Ниже сохранены проверки предыдущих этапов.

# План QA нативного NLHE-приложения

Актуальный план: [tests/test-plan.md](tests/test-plan.md).
Результат: [tests/report.md](tests/report.md).
Автоматизация: Swift Testing, Application/Core checks и XCUITest; команды и доказательства перечислены в отчёте.

Каталог и миграции schema1–5: [матрица CAT](tests/test-plan.md#cat--каталог-legacy-связи-и-schema-15-20-октября-2026), [результаты](tests/catalog-results.md).

## Пять учебных профилей ботов

Контракт: [bot-profiles.md](bot-profiles.md). Результаты: [tests/bot-results.md](tests/bot-results.md).
Целевые unit-тесты: BotPolicyTests; Application: Tools/AppChecks.swift;
Release Simulator benchmark: Tools/benchmark-bots.sh.

## Каталог, шаблон и восстановление — 21 октября 2026

Целевая матрица: [LESSON](tests/test-plan.md#lesson--шаблон-урока-и-прогресс).
Доказательства: [результаты](tests/lesson-template-results.md).

## M01–M04, редакция2

39 новых заданий и schema6: [план](tests/test-plan.md#foundation--m01m04),
[результаты](tests/foundations-results.md), [покрытие](tests/course-coverage.md).
Проверка XXXL отложена по согласованному объёму этапа.
