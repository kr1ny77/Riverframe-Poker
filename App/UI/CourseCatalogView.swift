import SwiftUI
import PokerCore

struct CourseCatalogView: View {
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let catalog = store.catalog
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d20) {
                if let error = store.errorMessage {
                    ErrorNotice(text: error)
                    Button("Повторить загрузку") { store.reload() }.buttonStyle(SecondaryButtonStyle())
                }
                if catalog.ignoredRecords > 0 {
                    Text("Записей вне текущего каталога: \(catalog.ignoredRecords). Исходная история сохранена; охват рассчитан по распознанным заданиям.")
                        .font(.footnote)
                }
                catalogHeader(catalog: catalog)

                ForEach(CourseLevel.allCases) { level in
                    let modules = CourseCatalog.modules.filter { $0.level == level }
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(level.title).font(.title3.weight(.bold))
                            Spacer()
                            Text("\(modules.count) модулей")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.muted)
                        }
                        let progress = catalog.progress(in: level)
                        Text("Охват: \(progress.covered)/\(progress.exerciseIDs.count) заданий").font(.footnote).foregroundStyle(AppTheme.muted)
                        DisclosureGroup("Подробнее об уровне") {
                            LearningMetricsView(progress: progress, identifier: "learning.metrics.level." + level.rawValue)
                        }
                        ForEach(modules) { module in
                            let progress = catalog.progress(in: module.id)
                            NavigationLink { CatalogModuleView(module: module) } label: {
                                CatalogModuleIndexRow(module: module, progress: progress)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("catalog.module.\(module.id.rawValue)")
                        }
                    }
                    .padding(AppTheme.Measure.d16)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                }
            }
            .padding(AppTheme.Measure.d16)
            .padding(.bottom, AppTheme.Measure.d16)
        }
        .lessonCanvas()
        .navigationTitle("Каталог курса")
    }

    private func catalogHeader(catalog: CourseCatalogSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Label("Каталог T01–T60", systemImage: "rectangle.grid.2x2")
                .font(.title2.weight(.bold))
            Text("Четыре уровня и 18 модулей. Откройте модуль, затем выберите одну задачу.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppTheme.Measure.d16) {
                    catalogMetric("Охват", value: "\(catalog.overallProgress.covered)/\(catalog.overallProgress.exerciseIDs.count)", identifier: "catalog.overall-progress")
                    catalogMetric("Темы", value: "60", identifier: "catalog.metric.topics")
                    catalogMetric("Модули", value: "18", identifier: "catalog.metric.modules")
                }
                VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
                    Text("Уникальных задач: \(catalog.overallProgress.covered)/\(catalog.overallProgress.exerciseIDs.count)")
                        .accessibilityIdentifier("catalog.overall-progress")
                }
            }
            Text("60 тем · 18 модулей · 4 уровня").accessibilityIdentifier("catalog.summary")
            Text("Прежние наборы и сохранённая история входят в общий охват.")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(AppTheme.Measure.d16)
        .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: AppTheme.radius))
    }

    private func catalogMetric(_ title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d2) {
            Text(value).font(.headline.monospacedDigit()).accessibilityIdentifier(identifier)
            Text(title).font(.caption).foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CatalogModuleView: View {
    let module: CatalogModule
    @EnvironmentObject private var store: PracticeStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d20) {
                LessonHeader(title: module.title, detail: "\(module.id.rawValue) · учебный модуль")
                VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                    Text("Сводка модуля").font(.headline)
                LearningMetricsView(progress: store.catalog.progress(in: module.id), identifier: "learning.metrics.module." + module.id.rawValue)
                LearningNextStepView(ids: store.catalog.progress(in: module.id).exerciseIDs)
                }
                .padding(AppTheme.Measure.d16)
                .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: AppTheme.radius))

                VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                    Text("Темы по порядку").font(.title3.weight(.bold))
                ForEach(CourseCatalog.topics.filter { $0.moduleID == module.id }) { topic in
                    NavigationLink {
                        CatalogTopicView(topic: topic)
                    } label: {
                        CatalogTopicIndexRow(topic: topic, progress: store.catalog.progress(for: topic.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("catalog.topic.\(topic.id.rawValue)")
                }
                }
            }
            .padding(AppTheme.Measure.d16)
            .padding(.bottom, AppTheme.Measure.d16)
        }
        .lessonCanvas()
        .navigationTitle(module.id.rawValue)
    }
}

struct CatalogTopicView: View {
    let topic: CatalogTopic
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let exercises = CourseCatalog.exercises(for: topic.id)
        let foundations = CourseCatalog.foundations(for: topic.id)
        let total = CourseCatalog.exerciseIDs(for: topic.id).count
        let catalog = store.catalog
        let progress = catalog.progress(for: topic.id)
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d18) {
                LessonHeader(title: topic.title, detail: topic.id.rawValue)
                if let error = store.errorMessage {
                    ErrorNotice(text: error)
                    Button("Повторить загрузку") { store.reload() }.buttonStyle(SecondaryButtonStyle())
                }
                if topic.moduleID == .m01 { CourseBoundariesIntroduction() }
                if let introduction = topic.introduction {
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
                        Text("Цель темы").font(.headline)
                        Text(introduction).font(.subheadline).foregroundStyle(AppTheme.muted)
                    }
                }
                if exercises.isEmpty && foundations.isEmpty {
                    Text("Тема включена в программу. Объяснения и упражнения готовятся.")
                } else {
                    topicSummary(progress: progress, total: total)
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                        Text("Выберите задачу").font(.title3.weight(.bold))
                        Text(progress.completedAvailableExercises ? "Все доступные ответы сохранены. Повторите ситуацию с другим входом." : "Начните с первой доступной ситуации.")
                            .font(.subheadline).foregroundStyle(AppTheme.muted)
                        ForEach(exercises) { exercise in
                            NavigationLink { LessonTemplateView(exercise: exercise, topicID: topic.id) } label: {
                                CatalogExerciseRow(
                                    title: exercise.title,
                                    detail: exercise.calculation.title,
                                    latestCorrect: catalog.observations.last(where: { $0.exerciseID == exercise.id })?.isCorrect,
                                    identifier: "catalog.latest.\(exercise.id.rawValue)"
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("catalog.exercise.\(exercise.id.rawValue)")
                        }
                    }
                }
                ForEach(foundations) { exercise in
                    NavigationLink { FoundationLessonView(exercise: exercise) } label: {
                        CatalogExerciseRow(
                            title: exercise.title,
                            detail: exercise.purpose.title + " · " + exercise.resultKind.title,
                            latestCorrect: catalog.observations.last(where: { $0.exerciseID == exercise.id })?.isCorrect,
                            identifier: "catalog.latest.\(exercise.id.rawValue)"
                        )
                    }.buttonStyle(.plain).accessibilityIdentifier("catalog.exercise.\(exercise.id.rawValue)")
                }
                DisclosureGroup("Сводка, прогресс и предпосылки") {
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                        LearningMetricsView(progress: progress, identifier: "learning.metrics.topic." + topic.id.rawValue)
                        LearningNextStepView(ids: progress.exerciseIDs)
                        Text("Этот охват относится к опубликованным задачам. Общие задания учитываются в каждой связанной теме по одной сохранённой попытке.")
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                        if !topic.prerequisites.isEmpty {
                            Divider()
                            Text("Предпосылки").font(.subheadline.weight(.semibold))
                        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                            ForEach(topic.prerequisites, id: \.self) { id in
                                if let prerequisite = CourseCatalog.topics.first(where: { $0.id == id }) {
                                    NavigationLink { CatalogTopicView(topic: prerequisite) } label: {
                                        Text("\(id.rawValue) · \(prerequisite.title)")
                                    }
                                }
                            }
                            }
                        }
                    }
                    .padding(.top, AppTheme.Measure.d8)
                }
                Text("Редакция каталога: \(CourseCatalog.contentVersion)").font(.footnote).foregroundStyle(AppTheme.muted)
            }.padding(AppTheme.Measure.d16)
        }
        .lessonCanvas().navigationTitle(topic.id.rawValue)
    }

    private func topicSummary(progress: CatalogTopicProgress, total: Int) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
            Text("Охват текущих упражнений: \(progress.covered)/\(total)")
                .font(.headline.monospacedDigit())
                .accessibilityIdentifier("catalog.progress.\(topic.id.rawValue)")
            Text("Ответов: \(progress.observations.count). Последние верные: \(progress.latestCorrect)/\(progress.covered).")
                .font(.footnote).foregroundStyle(AppTheme.muted)
                .accessibilityIdentifier("catalog.answers.\(topic.id.rawValue)")
        }
        .padding(AppTheme.Measure.d16)
        .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: AppTheme.radius))
    }
}

private struct CatalogModuleIndexRow: View {
    let module: CatalogModule
    let progress: CatalogTopicProgress

    var body: some View {
        HStack(spacing: AppTheme.Measure.d12) {
            Text(module.id.rawValue).font(.caption.weight(.bold)).foregroundStyle(AppTheme.accent)
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: AppTheme.Measure.d3) {
                Text(module.title).font(.headline).foregroundStyle(AppTheme.text)
                Text("\(CourseCatalog.topics.filter { $0.moduleID == module.id }.count) тем · \(progress.covered)/\(progress.exerciseIDs.count) задач")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AppTheme.muted)
        }
        .frame(minHeight: 44)
        .padding(.vertical, AppTheme.Measure.d6)
        .contentShape(Rectangle())
    }
}

private struct CatalogTopicIndexRow: View {
    let topic: CatalogTopic
    let progress: CatalogTopicProgress

    var body: some View {
        HStack(spacing: AppTheme.Measure.d12) {
            Text(topic.id.rawValue).font(.caption.weight(.bold)).foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: AppTheme.Measure.d3) {
                Text(topic.title).font(.headline).foregroundStyle(AppTheme.text)
                Text("\(progress.covered)/\(progress.exerciseIDs.count) задач · \(progress.observations.count) ответов")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(AppTheme.muted)
        }
        .frame(minHeight: 44)
        .padding(.vertical, AppTheme.Measure.d6)
        .contentShape(Rectangle())
    }
}

private struct CatalogExerciseRow: View {
    let title: String
    let detail: String
    let latestCorrect: Bool?
    let identifier: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Measure.d12) {
            Image(systemName: latestCorrect == true ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(latestCorrect == true ? AppTheme.success : AppTheme.muted)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppTheme.Measure.d3) {
                Text(title).font(.headline).foregroundStyle(AppTheme.text)
                Text(detail).font(.footnote).foregroundStyle(AppTheme.muted)
                if let latestCorrect {
                    Text(latestCorrect ? "Последний ответ: верно по условию." : "Последний ответ: есть ошибка.")
                        .font(.footnote)
                        .foregroundStyle(latestCorrect ? AppTheme.success : AppTheme.warning)
                        .accessibilityIdentifier(identifier)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(AppTheme.muted)
        }
        .frame(minHeight: 52)
        .padding(AppTheme.Measure.d12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .contentShape(Rectangle())
    }
}


struct CatalogProgressSection: View {
    @EnvironmentObject private var store: PracticeStore
    var body: some View {
        let catalog = store.catalog
        let overall = catalog.overallProgress
        Section("Учебная мастерская") {
            LearningMetricsView(progress: overall, identifier: "learning.metrics.total")
            Text("Уникальных задач: \(overall.covered)/\(overall.exerciseIDs.count). Ответов: \(overall.observations.count).")
                .accessibilityIdentifier("progress.catalog.summary")
            Text("Общие задания входят в несколько тем. В общем охвате каждая задача учитывается один раз.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            NavigationLink { CourseCatalogView() } label: {
                Label("Открыть каталог T01–T60", systemImage: "rectangle.grid.2x2")
            }.accessibilityIdentifier("progress.catalog")

            DisclosureGroup("Следующий шаг") {
                LearningNextStepView()
                    .padding(.top, AppTheme.Measure.d8)
            }

            DisclosureGroup("Повторение понятий") {
                LearningReviewQueueView()
                    .padding(.top, AppTheme.Measure.d8)
            }

            LearningProjectCriterionView()

            ForEach(CourseLevel.allCases) { level in
                DisclosureGroup(level.title) {
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                        let levelProgress = catalog.progress(in: level)
                        LearningMetricsView(progress: levelProgress, identifier: "learning.metrics.level." + level.rawValue)
                        LearningNextStepView(ids: levelProgress.exerciseIDs)
                        ForEach(CourseCatalog.modules.filter { $0.level == level }) { module in
                            moduleProgress(module, catalog: catalog)
                        }
                    }
                    .padding(.top, AppTheme.Measure.d8)
                }.accessibilityIdentifier("learning.level." + level.rawValue)
            }
        }
    }

    @ViewBuilder
    private func moduleProgress(_ module: CatalogModule, catalog: CourseCatalogSnapshot) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                let progress = catalog.progress(in: module.id)
                LearningMetricsView(progress: progress, identifier: "learning.metrics.module." + module.id.rawValue)
                LearningNextStepView(ids: progress.exerciseIDs)
                ForEach(CourseCatalog.topics.filter { $0.moduleID == module.id }) { topic in
                    let progress = catalog.progress(for: topic.id)
                    NavigationLink { CatalogTopicView(topic: topic) } label: {
                        CatalogTopicIndexRow(topic: topic, progress: progress)
                    }
                    .accessibilityIdentifier("progress.topic.\(topic.id.rawValue)")
                }
            }
            .padding(.top, AppTheme.Measure.d8)
        } label: {
            let progress = catalog.progress(in: module.id)
            Text("\(module.id.rawValue) · \(module.title) · \(progress.covered)/\(progress.exerciseIDs.count)")
        }
        .accessibilityIdentifier("progress.module.\(module.id.rawValue)")
    }
}

/// Always available before advanced study; the same introduction serves M01.
struct CourseBoundariesIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Text("Перед практикой").font(.headline)
                .accessibilityIdentifier("course.boundaries.introduction")
            Text("Фишки виртуальные. Задайте время окончания и завершайте занятие при усталости или раздражении.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            if let topic = CourseCatalog.topics.first(where: { $0.id == .t59 }) {
                NavigationLink { CatalogTopicView(topic: topic) } label: {
                    Label("Личные границы · T59", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("course.boundaries.open")
            }
            DisclosureGroup("Почему это важно") {
                VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                    Text("Результат одной раздачи зависит от случайности; решение оценивайте по доступным тогда данным.")
                    Text("При повторяющихся трудностях с соблюдением границ обсудите их с человеком, которому доверяете, или квалифицированным специалистом.")
                    Text("Подробный разбор риска находится в M18. Это учебные рекомендации по организации практики.")
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .padding(.top, AppTheme.Measure.d8)
            }
        }
        .padding(AppTheme.Measure.d16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
    }
}

/// The same scoped metrics appear for a topic, module, level and the full course.
struct LearningMetricsView: View {
    let progress: CatalogTopicProgress
    let identifier: String
    var body: some View {
        let metrics = LearningMetrics(progress: progress)
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Text("Попыток: \(metrics.attempts) · разных шаблонов: \(metrics.distinctTemplates)")
                .font(.headline.monospacedDigit()).accessibilityIdentifier(identifier)
            SwiftUI.ProgressView(value: Double(progress.covered), total: Double(max(1, progress.exerciseIDs.count)))
                .tint(AppTheme.accent).accessibilityLabel("Охват задач").accessibilityValue("\(progress.covered) из \(progress.exerciseIDs.count)")
            Text("Охват: \(progress.covered)/\(progress.exerciseIDs.count) заданий").font(.subheadline)
            if let accuracy = metrics.firstTemplateAccuracy {
                Text("Точность на новых шаблонах: \(metrics.firstTemplateCorrect)/\(metrics.firstTemplateAttempts) · \((accuracy * 100).formatted(.number.precision(.fractionLength(1)))) %")
                    .font(.subheadline)
            } else { Text("Точность на новых шаблонах: пока нет ответов").font(.subheadline) }
            if let date = metrics.lastChecked {
                Text("Последняя проверка: " + date.formatted(date: .abbreviated, time: .shortened)).font(.footnote).foregroundStyle(AppTheme.muted)
            } else { Text("Последняя проверка: ещё не было").font(.footnote).foregroundStyle(AppTheme.muted) }
            if metrics.smallSample { Text("Малая выборка: вывод относится к встреченным задачам.").font(.footnote).foregroundStyle(AppTheme.muted) }
            DisclosureGroup("Как читать эти числа") {
                VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                    Text("Новый шаблон — первый ответ по E-ID. Повторы сохраняются отдельно.")
                    Text(metrics.projectCriterionStatus)
                    Text("Учебные ответы и баланс виртуальных фишек ведутся отдельно.")
                }.font(.footnote).foregroundStyle(AppTheme.muted)
            }.font(.footnote)
        }
    }
}

struct LearningProjectCriterionView: View {
    var body: some View {
        DisclosureGroup("Проектный критерий curriculum") {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                Text("По уровню: ≥90 % на 20 новых заданиях; отсутствие критических ошибок в последних пяти; ≥80 % на 10 новых заданиях через семь дней.")
                Text("Это проектный критерий учебной оценки. Он требует педагогической проверки. Показанные ответы характеризуют работу с задачами; профессиональная квалификация оценивается отдельно.")
                Text("Текущий каталог содержит конечный набор шаблонов. После их исчерпания нужны новые независимые задачи. Проверка критических причин и объяснений требует отдельного разбора.")
            }.font(.footnote).foregroundStyle(AppTheme.muted)
        }
    }
}

@MainActor @ViewBuilder func learningDestination(_ id: CatalogExerciseID) -> some View {
    if let exercise = FoundationLesson.exercise(id) {
        FoundationLessonView(exercise: exercise)
    } else if let exercise = CourseCatalog.exercises.first(where: { $0.id == id }), let topic = exercise.topicIDs.first {
        LessonTemplateView(exercise: exercise, topicID: topic)
    }
}

struct LearningNextStepView: View {
    @EnvironmentObject private var store: PracticeStore
    var ids: Set<CatalogExerciseID> = CourseCatalog.allExerciseIDs
    var body: some View {
        let learning = store.learning()
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Text("Следующий шаг по курсу").font(.headline)
            if let id = learning.recommendation(in: ids) {
                NavigationLink { learningDestination(id) } label: {
                    Label(learningTaskTitle(id), systemImage: "arrow.right.circle")
                }.accessibilityIdentifier("learning.recommendation")
                Text("Сначала — наступившее повторение; затем — новый шаблон. Будущие повторы доступны для добровольной практики.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            } else {
                Text("Новых шаблонов и наступивших повторов в этом разделе пока нет. Можно вернуться к разбору или открыть другой раздел.")
            }
        }
    }
}

private func learningTaskTitle(_ id: CatalogExerciseID) -> String {
    FoundationLesson.exercise(id)?.title ?? CourseCatalog.exercises.first(where: { $0.id == id })?.title ?? id.rawValue
}

struct LearningReviewQueueView: View {
    @EnvironmentObject private var store: PracticeStore
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let learning = store.learning(now: context.date)
            VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                Text("Повторение понятий").font(.headline).accessibilityIdentifier("learning.review.queue")
                Text("День означает 24 часа; время показано в часовом поясе устройства. Интервалы после ошибки: 1, 3, 7 и 21 день. После успешной отложенной проверки следующий интервал отсчитывается от неё. Ранний ответ остаётся практикой; новая ошибка начинает цикл заново.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                if learning.reviews.isEmpty {
                    Text("Запланированных повторов пока нет.")
                }
                ForEach(learning.reviews, id: \.id) { item in
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                        Text("\(item.topicID.rawValue) · \(item.kind.title)").font(.subheadline.weight(.medium))
                        Text("Проверка \(item.stage + 1)/4 · " + item.dueDate.formatted(date: .abbreviated, time: .shortened))
                        Text(item.dueDate <= context.date ? "Срок наступил" : "Запланировано; сейчас доступна ранняя практика")
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                        if let id = item.exerciseID {
                            NavigationLink { learningDestination(id) } label: {
                                Text("Другая задача: " + learningTaskTitle(id))
                            }.accessibilityIdentifier("learning.review.open." + item.topicID.rawValue)
                        } else {
                            Text("Для этого понятия нужен дополнительный шаблон. Срок сохранён.")
                        }
                    }
                }
                DisclosureGroup("История категорий ошибок") {
                    ForEach(learning.diagnostics.sorted { $0.date > $1.date }) { diagnostic in
                        VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                            Text(learningTaskTitle(diagnostic.exerciseID)).font(.subheadline.weight(.medium))
                            Text(diagnostic.date, format: .dateTime.day().month().year().hour().minute())
                            Text(diagnostic.kind.title)
                            LearningErrorEditor(attemptID: diagnostic.id)
                        }
                    }
                }
                Text("Категория относится к условию задания или вашему уточнению. Интервалы — учебная настройка, эффективность которой требует отдельной проверки.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
        }
    }
}

struct LearningErrorEditor: View {
    let attemptID: UUID
    @EnvironmentObject private var store: PracticeStore
    @State private var selected: LearningErrorKind = .unspecified
    @State private var saved = false
    @State private var failure: String?
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
            Text("Категория ошибки").font(.headline)
            Text("Начальная категория выбрана по задаче. Уточните причину после разбора: расчёт, правило, модель или исполнение.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            Picker("Тип ошибки", selection: $selected) {
                ForEach(LearningErrorKind.allCases, id: \.self) { kind in Text(kind.title).tag(kind) }
            }.pickerStyle(.menu).accessibilityIdentifier("learning.error.kind")
            Button("Сохранить категорию") {
                do { try store.classifyError(attemptID: attemptID, kind: selected); saved = true; failure = nil }
                catch { failure = "Категория не сохранена. Повторите запись." }
            }.accessibilityIdentifier("learning.error.save")
            if saved { Text("Категория сохранена.").accessibilityIdentifier("learning.error.saved") }
            if let failure { ErrorNotice(text: failure) }
            Text("Повтор назначен локально. Дата и другая задача показаны в разделе «Повторение понятий».")
                .font(.footnote).foregroundStyle(AppTheme.muted)
        }
        .onAppear { selected = store.diagnostics.first(where: { $0.id == attemptID })?.kind ?? .unspecified }
        .onChange(of: selected) { _, _ in saved = false }
    }
}
