# Приёмка M10–M13 — редакция 4

Дата: 22 октября 2026. Baseline: `a77cc08`. Среда: macOS arm64,
Xcode Simulator iPhone 17e / iOS 27.0. Материалы и проверки выполняются локально.

## Реализовано

49 новых задач для 15 тем:

- M10: T12/T13/T36/T38 — 13 задач: fold equity, EV ставки/рейза/all-in,
  покрытие короткого стека, check-raise, сайзинг и план банка/стека по улицам.
- M11: T30/T31/T33/T40 — 13 задач: range/nut advantage, условная реализация,
  board coverage, multiway и доступные банки. T32 переиспользуется как предпосылка.
- M12: T19/T20 — 6 задач: MDF, bluff:value, доля bluff, bluff-catching и removal.
- M13: T45/T46/T47/T49/T50 — 17 задач: ICM R0/R1, риск, выплаты,
  push/fold и ценность конечных стеков после side pots.

У каждой темы есть понятие, перенос и граница; T13/T30/T46/T50 имеют четвёртый пример.
У каждой задачи есть контекст, типизированный ответ, разбор, типичная ошибка,
рамки «Термин»/«Метод», схема, статус результата и research-якорь.
Стратегические частоты служат входами условных моделей.

MDF `P/(P+b)`, отношение `B/V=b/(P+b)` и доля `B/(B+V)=b/(P+2b)`
показывают разные знаменатели. Формулы относятся к явно ограниченной HU river toy-модели.
Для конкретной руки call EV зависит от совместимых диапазонов и их весов.

## ICM

Все три места R0/R1, полный payout ladder и fold/win/lose/tie состояния показаны
в условиях. Перебор мест вычисляет ценность каждой ветви; затем W/T/L вероятности
взвешивают эти значения. Используется Double с явным округлением в интерфейсе.

R0 при q=50%: chip EV колла `+1` фишка; ICM call `32,5236074` против fold `32,6153846`.
Порог ICM `50,5826093%`; chip threshold `47,6190476%`; разница `2,9635617 п.п.`.
Ничья: terminal stacks `48/31/21`, `U_tie(B)=32,9855890944`.
T50 leaf `150/0/30` при выплатах `90/60/30`: ICM A=85 условных единиц.

Калькулятор ограничен полями 2–6 игроков. Один нулевой стек получает последнее место;
несколько нулевых стеков требуют правила распределения мест и отклоняются.
ICM исключает будущую игру, различия навыка и bounty. Турнирные ситуации доступны
в учебных задачах; игровой стол сохраняет 6-max cash-practice.

## Проверки

| Проверка | Результат | Доказательство |
| --- | --- | --- |
| `swift test -c release` | PASS:122 теста | [unit-release](evidence/advanced-v4/unit-release.txt) |
| Независимый ICM oracle | PASS:10 случаев, точные Fraction/перестановки | [fixture](../../Tests/Fixtures/course-v4-math-oracle.json), [генератор](../../Tools/check-advanced-course.py) |
| Совместимость132→181 | PASS: payload/UUID/даты/оценки и completion8/8 | CourseAdvancedTests; [baseline fixture](../../Tests/Fixtures/course-v3-all132.json), [происхождение](../../Tests/Fixtures/README.md) |
| Core/Application/build | PASS:24/24 Core,10937 утверждений; Application и iOS build | [verify](evidence/advanced-v4/verify.txt) |
| 15 тем: маршрут/ответ/запись/relaunch | PASS:15/15 тем,15 попыток после relaunch | [summary](evidence/course-20261022-131452/summary.json), [вывод](evidence/course-20261022-131452/flows.txt), [скриншоты](evidence/course-20261022-131452/screenshots/manifest.json) |
| ICM tie/порог/risk premium/side-pot value | PASS:4 задачи; числовые ключи, деревья и relaunch | [summary](evidence/course-20261022-132830/summary.json), [вывод](evidence/course-20261022-132830/flows.txt), [скриншоты](evidence/course-20261022-132830/screenshots/manifest.json) |
| Сохранность движка/ботов/старых провайдеров | 18 файлов побайтно совпадают с baseline | [SHA-256](evidence/advanced-v4/protected-files.json) |

Проверены неверные ответы, неверные/нечисловые входы, нулевые знаменатели,
переполнение, очень малые стеки, одинаковые выплаты, WTA, перестановки и масштабирование.
Физические комбинации проверены отдельным перечислением пар и evaluator.

Числовые паспорта: [агрессия](../research/course-aggression-validation.md),
[распределения](../research/course-distributions-validation.md),
[ICM](../research/course-icm-validation.md).
[Проверенные первичные основания](../research/course-advanced-research.md).
[Матрица60тем/18модулей](course-coverage.md),
[манифест181E-ID](evidence/advanced-v4/catalog-manifest.json).

## Ограничения приёмки

В обоих UI-прогонах воспроизведено прежнее UI-WARN-001 `Invalid frame dimension`.
В существующем setup тестового target остаются предупреждения actor isolation;
Simulator сообщает diagnostic SDK/debugger version. Оба сценария завершились успешно.
Просмотр обычного размера текста подтверждает читаемые узлы/знаменатели диаграммы.
Все 49 математических ключей и запись покрыты unit-тестами; UI проверяет
представительные задачи каждого T-ID и дополнительные ICM задачи.
XXXL и расширенная ручная VoiceOver/адаптивная приёмка отложены пользователем.
Следующий учебный этап: M14–M18.
