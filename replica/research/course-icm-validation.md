# Проверка учебного блока ICM M13

Дата проверки: 2026-10-21. Блок реализует пять тем: T45, T46, T47, T49 и T50. Все рекомендации остаются условными: численные результаты точно следуют из явно заданных стеков, выплат и дерева outcomes, а ICM не предсказывает диапазоны, будущую игру, skill edge, bounty или изменения структуры.

## Алгоритм и границы

`CourseICM.prizeEquities` перечисляет порядки мест для поля от 2 до 6 игроков. На каждом шаге вероятность следующего места равна `stack / sum(remaining stacks)`. Затем payout места умножается на вероятность порядка; сумма prize equity всех игроков равна сумме payouts.

Входы: конечный vector стеков всего поля, неотрицательный невозрастающий vector payouts той же длины, положительная сумма стеков. Один нулевой стек получает последний payout как уже выбывший игрок. Два и более одновременных нулевых стеков получают ошибку `multipleEliminationsNeedPlacementRule`: порядок выплат зависит от отдельного правила турнира, seat order не используется. Равные payouts допустимы.

Единицы ICM — искусственные payout units. Chip EV измеряется в фишках. Смешивать их в одной сумме нельзя.

## Независимые контрольные векторы

### R0: T45 и T46

MTT, A/B/C: initial `48/31/21`, после обязательных взносов и фолда A terminal fold `48/30/22`; payouts `50/30/20`. Для B:

- `U_fold = 32.6153846154`.
- win leaf `48/52/0`: `U_win = 40.4`.
- lose leaf `48/10/42`: `U_lose = 24.6472148541`.
- при `w=.5, t=0, l=.5`: `EV = .5×40.4 + .5×24.6472148541 = 32.5236074271`, что ниже fold на `0.0917771883` payout units.
- chip EV того же call: `.5×42−20 = +1 chip`; различие выводов следует из разных единиц и terminal leaves.
- порог двух ветвей: `(U_fold-U_lose)/(U_win-U_lose) = 50.5826093 %`.
- chip-EV порог того же call: `20/42 = 47.6190476 %`.
- `G=U_win-U_fold`, `L=U_fold-U_lose`, `BF=L/G=1.023579` в принятой конвенции.

При tie используется отдельный leaf: `w×U_win + t×U_tie + l×U_lose`, где знаменатель вероятностей `w+t+l=1`. В R0 concrete tie leaf: B=`AsQc`, C=`AcQh`, board `Qd7c4h2s9d`, split pot даёт terminal stacks `48/31/21`. Для B `U_tie=32.9855890944`; тест дополнительно использует w=.45/t=.10/l=.45. Half-tie showdown equity не заменяет `U_tie`.

### R1: T47

Bubble vector payouts `50/30/0`. C fold leaf `40/41/19` даёт `U_fold(C)=17.2610169492`; win leaf `40/20/40` даёт `31`; lose leaf `40/60/0` даёт `0`. При `w=.6, t=0, l=.4`: `EV=.6×31=18.6`. Изменение payout vector требует полного пересчёта каждого ICM leaf.

### T49: учебное EV-дерево push/fold

В отдельной chip-EV модели риск shove `10 BB`, dead money `2.5 BB`, equity при call `0`:

`EV = F×2.5 − (1−F)×10`.

Нулевой EV даёт `F = 10/(10+2.5) = 80 %`. Ветка call с заданной win probability требует свои win/lose/tie payoffs. Bubble-решение заменяет chip payoffs на ICM terminal leaves с полем стеков и payouts.

### T50: exact pot accounting перед ICM

Взносы A/B/C `100/60/20`:

| Слой | Формула | Фишки | Eligible |
| --- | --- | ---: | --- |
| Main | `20×3` | 60 | A/B/C |
| Side | `(60−20)×2` | 80 | A/B |
| Refund | `100−60` | 40 | A |
| Всего | `60+80+40` | 180 | — |

Три проверенные terminal states: B выигрывает board и получает оба оспариваемых слоя — `A/B/C=40/140/0`; C получает main, A получает side — `120/0/60`; main делят A/C, side и refund получает A — `150/0/30`. Каждый vector сохраняет 180. В трёхместном учебном field с payouts `90/60/30` последний leaf даёт A `5/6×90 + 1/6×60 = 85`; B — единственный zero stack и получает явно заданный последний payout 30. Для ICM добавляют всех игроков поля, например folded D со стеком 70, и полный payout vector. Право на pot и принадлежность к ICM field — разные списки.

## Проверка реализации

`CourseICMTests` сверяет R0 с закрытой формулой для второго места, conservation payouts, scale invariance, permutation symmetry, equal payouts, winner-take-all, один zero stack, ошибку нескольких zero stacks, W/T/L знаменатель и side-pot conservation. Тесты проверяют typed Swift значения; текст карточек не исполняется как формула.

## Источники и статус

- Gilbert, 2009, [Independent Chip Model risk aversion](https://arxiv.org/abs/0911.3100) — концептуальная основа ICM.
- ICMIZER, [How ICM calculations work](https://www.icmizer.com/en/blog/how-icmizer-makes-icm-calculations/) (2021-04-08) — различение chip EV, $EV и расчёта по leaves.

Задачи и числа R0/R1 — оригинальные учебные модели из локальной карты знаний. В них отсутствуют лицензированные solver tables, поэтому блок не утверждает универсальные частоты, shove ranges или размеры ставок.
