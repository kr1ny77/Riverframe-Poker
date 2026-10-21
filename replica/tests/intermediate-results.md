# Приёмка M05–M09 — редакция 3

Дата: 21 октября 2026. Baseline: `67e44b4`. Среда: macOS arm64,
Xcode Simulator iPhone 17e / iOS 27.0. Исходники и все проверки выполнены локально.

## Реализовано

50 новых задач на 16 T-ID: T10/T16/T14/T15, T23–T27,
T17/T32/T29/T39/T34/T35/T37. Каждая тема содержит понятие, перенос и границу модели;
T32/T34 дополнены четвёртым примером. У каждой задачи есть условие, допущения,
типизированный ключ, объяснение, типичная ошибка и research-якорь.

T18 сохраняет шесть прежних задач removal. T21/T22 переиспользуются как предпосылки
стартовых рук и условных чартов. Число уникальных E-ID: 132 = 43 legacy + 39 v2 + 50 v3.
Модульные суммы учитывают совместные задачи; общий охват устраняет повторения.

Новый MC-отчёт показывает метод SplitMix64/rejection v1, seed20261021, N20000,
W/T/L18310/0/1690, долю91,55%, SE0,1967п.п. и приближённый 95%-интервал
91,1645–91,9355%. Точный независимый ориентир: 907/990.
Каталог отображает замороженный опыт; случайные вычисления вызываются тестами.
Условные модели содержат позиции, стеки, ставки, единицы, знаменатель и границы.
Полные стратегические диапазоны требуют отдельного набора данных и источника.

## Результаты проверок

| Проверка | Результат | Доказательство |
| --- | --- | --- |
| `swift test -c release` | PASS: 102 теста | [unit-release](evidence/intermediate-v3/unit-release.txt) |
| `./Tools/verify.sh` | PASS | [полный вывод](evidence/intermediate-v3/verify.txt) |
| Core | PASS: 24/24 группы, 10937 утверждений | [core-checks](evidence/intermediate-v3/core-checks.txt) |
| Сборка iOS Simulator | BUILD SUCCEEDED | [ios-build](evidence/intermediate-v3/ios-build.txt) |
| PracticeStore/Application, боты, игра | PASS; 6000 фишек сохранены | [app-checks](evidence/intermediate-v3/app-checks.txt) |
| `testIntermediateTopicsAndRelaunch` | PASS: все 16 новых T-ID + прежняя T03; 17 записей до/после relaunch | [summary](evidence/course-20261021-180654/summary.json), [вывод](evidence/course-20261021-180654/flows.txt), [скриншоты](evidence/course-20261021-180654/screenshots/manifest.json) |
| `testMonteCarloReportAndBayesRounding` | PASS: отчёт/SE/интервал, ввод91,55 и57,14, округлённый ключ, восстановление обеих попыток | [summary](evidence/course-20261021-182114/summary.json), [вывод](evidence/course-20261021-182114/flows.txt), [скриншоты](evidence/course-20261021-182114/screenshots/manifest.json) |
| Совместимость82→132 | PASS: все прежние payload, UUID, даты, результаты и completion8/8 | CourseIntermediateTests; [fixture](../../Tests/Fixtures/course-v2-all82.json), [происхождение](../../Tests/Fixtures/README.md) |
| Движок, evaluator, боты, PracticeHistory/Store, старые провайдеры | 15 файлов побайтно совпадают с baseline | [SHA-256](evidence/intermediate-v3/protected-files.json) |

Независимые числовые разборы:
[оценки/рейк](../research/course-estimation-validation.md),
[префлоп](../research/course-preflop-validation.md),
[диапазоны/постфлоп](../research/course-ranges-postflop-validation.md).
[Матрица60тем/18модулей](course-coverage.md) построена по
[манифесту скомпилированного каталога](evidence/intermediate-v3/catalog-manifest.json).

## Ограничения приёмки

- UI проверяет по одной задаче каждого дополненного T-ID; все 50 ключей и сохранение
  покрыты unit-тестами. Переиспользованный T18 опирается на прежние проверки маршрута.
- XCUITest сообщает прежний UI-WARN-001 `Invalid frame dimension` во время запуска.
  Оба сценария завершились успешно. В тестовом target остаются предупреждения
  actor isolation в существующем setup; Simulator также сообщает diagnostic версии SDK.
- XXXL и расширенная ручная VoiceOver/адаптивная приёмка отложены пользователем.
  Просмотр скриншота MC подтверждает читаемый отчёт в обычном размере текста.
- Контент M10–M18 остаётся следующим отдельным этапом.
