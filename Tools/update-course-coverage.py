#!/usr/bin/env python3
"""Render coverage from the compiled Swift catalog; preserve prior test provenance."""
import csv
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / '.build/course-catalog-manifest.json').read_text())
assert len(manifest['topics']) == 60 and len(manifest['modules']) == 18
assert manifest['uniqueTasks'] == 226 and manifest['finalTasks'] == 45
path = root / 'replica/tests/course-coverage.csv'
previous = {r['ID']: r for r in csv.DictReader(path.open())}
rows = []
for topic in manifest['topics']:
    old = previous.get(topic['id'], {})
    tests = old.get('Тесты', old.get('Проверки', 'Прежние unit/Application/UI проверки'))
    module = int(topic['module'][1:])
    if module >= 14:
        provider = 'CourseTheoryTests' if module <= 15 else ('CourseReviewTests' if module <= 17 else 'CourseRiskTests')
        tests = provider + '; CourseCompletionTests: keys/route/181→226/retry/relaunch; UI testFinalTopicsAndRelaunch'
    elif 'CourseCompletionTests' not in tests:
        tests += '; CourseCompletionTests: полный каталог/сохранение181'
    evidence = '; '.join(topic['evidence'])
    if module >= 14:
        evidence += '; процессные рекомендации — учебная рамка; эффективность продукта и поведение поля отдельно не измерены'
    rows.append({'ID': topic['id'], 'Название': topic['title'], 'Модуль': topic['module'],
                 'Статус': topic['status'], 'Маршрут': topic['route'],
                 'Прежние': len(topic['legacyIDs']), 'Foundation': len(topic['foundationIDs']),
                 'Задания': '; '.join(topic['legacyIDs'] + topic['foundationIDs']),
                 'Тесты': tests, 'Доказательность': evidence,
                 'Ограничения': 'Расширение сценариев; ручная VoiceOver/XXXL приёмка отложена'})
with path.open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
    writer.writeheader(); writer.writerows(rows)
lines = ['# Покрытие курса T01–T60 / M01–M18', '',
         '25 октября 2026. Каталог v5: **60/60 тем, 18/18 модулей, 226 уникальных заданий**. Новые M14–M18: 45 задач, по три на тему (понятие, перенос, граница). Старые 181 ID и результаты сохранены.', '',
         '«Блок доступен» означает наличие маршрута, задания, проверки ответа и локального сохранения. Математика подтверждает заданные входы. Стратегические примеры и процессные рекомендации имеют явно указанные ограничения; образовательная эффективность продукта отдельно не измерена.', '',
         '## Модули', '', '| ID | Название | Темы | Уникальные задачи | Статус |', '| --- | --- | --- | --- | --- |']
for module in manifest['modules']:
    lines.append(f"| {module['id']} | {module['title']} | {', '.join(module['topics'])} | {module['uniqueTasks']} | Блоки тем доступны |")
lines += ['', 'Общие E-ID учитываются единожды в охвате курса. T11 переиспользует pot odds и EV-call; T02/T21 — части урока позиций; T06/T18 — блокеры. T32 остаётся единственным источником урока форм диапазонов.', '',
          '## Темы', '', '| ID / модуль | Название | Маршрут | Задания | Тесты | Статус доказательности |', '| --- | --- | --- | --- | --- | --- |']
for row in rows:
    cells = [row['ID']+' / '+row['Модуль'], row['Название'], row['Маршрут'], row['Задания'], row['Тесты'], row['Статус']+'; '+row['Доказательность']]
    lines.append('| ' + ' | '.join(str(c).replace('|', '/') for c in cells) + ' |')
lines += ['', '## Границы этапа', '',
          '- Раннее введение о виртуальных фишках, личных пределах и паузах видно на входе в курс и в каждой теме M01; прямая ссылка ведёт в T59.',
          '- M14: авторские учебные отчёты и модели. Внешние solver-решения и лицензированные чарты в приложение не включены.',
          '- M16: сателлитные выплаты существуют в учебных задачах. Практический стол сохраняет формат 6-max cash-practice.',
          '- M17: восстановление раздачи, заметки и план повторения разбираются в сценариях. Личный редактор заметок, календарь и таймер не входят в этот этап.',
          '- M18: условная модель разорения, условный Байес и ограничения наблюдений. Полевая надёжность tells требует отдельной выборки; медицинские и финансовые выводы не вычисляются.',
          '- Ручная расширенная проверка VoiceOver, XXXL и адаптивной вёрстки отложена пользователем. Существующая UI-WARN-001 отслеживается отдельно.', '',
          'Воспроизведение: собрать Release PokerCore, выполнить `Tools/export-course-catalog.sh`, затем `python3 Tools/update-course-coverage.py`. [Результаты этапа](completion-results.md).']
(root / 'replica/tests/course-coverage.md').write_text('\n'.join(lines)+'\n')
