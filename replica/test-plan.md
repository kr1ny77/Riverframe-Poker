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
