import SwiftUI
import PokerCore

struct CourseCatalogView: View {
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let catalog = store.catalog
        List {
            Section {
                if let error = store.errorMessage {
                    ErrorNotice(text: error)
                    Button("Повторить загрузку") { store.reload() }
                }
                if catalog.ignoredRecords > 0 {
                    Text("Записей вне текущего каталога: \(catalog.ignoredRecords). Исходная история сохранена; охват рассчитан по распознанным заданиям.")
                        .font(.footnote)
                }
                Text("Уникальных задач: \(catalog.overallProgress.covered)/\(catalog.overallProgress.exerciseIDs.count)")
                    .accessibilityIdentifier("catalog.overall-progress")
                Text("60 тем · 18 модулей · 4 уровня")
                    .accessibilityIdentifier("catalog.summary")
                Text("Все темы содержат задания. Прежние наборы и сохранённая история включены в общий охват.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            ForEach(CourseLevel.allCases) { level in
                Section(level.title) {
                    LearningMetricsView(progress: catalog.progress(in: level), identifier: "learning.metrics.level." + level.rawValue)
                    ForEach(CourseCatalog.modules.filter { $0.level == level }) { module in
                        NavigationLink {
                            CatalogModuleView(module: module)
                        } label: {
                            VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
                                Text("\(module.id.rawValue) · \(module.title)")
                                Text("Тем: \(CourseCatalog.topics.filter { $0.moduleID == module.id }.count)")
                                let progress = catalog.progress(in: module.id)
                                Text(progress.exerciseIDs.isEmpty ? "Материал готовится" : "Охват: \(progress.covered)/\(progress.exerciseIDs.count) разных задач")
                                    .font(.footnote).foregroundStyle(AppTheme.muted)
                            }
                        }
                        .accessibilityIdentifier("catalog.module.\(module.id.rawValue)")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
        .navigationTitle("Каталог курса")
    }
}

private struct CatalogModuleView: View {
    let module: CatalogModule
    @EnvironmentObject private var store: PracticeStore
    var body: some View {
        List {
            Section(module.title) {
                LearningMetricsView(progress: store.catalog.progress(in: module.id), identifier: "learning.metrics.module." + module.id.rawValue)
                LearningNextStepView(ids: store.catalog.progress(in: module.id).exerciseIDs)
                ForEach(CourseCatalog.topics.filter { $0.moduleID == module.id }) { topic in
                    NavigationLink {
                        CatalogTopicView(topic: topic)
                    } label: {
                        VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
                            Text("\(topic.id.rawValue) · \(topic.title)")
                            let count = CourseCatalog.exerciseIDs(for: topic.id).count
                            Text(count == 0 ? "Материал готовится" : "Доступно упражнений: \(count) · учебный блок")
                                .font(.footnote).foregroundStyle(AppTheme.muted)
                        }
                    }
                    .accessibilityIdentifier("catalog.topic.\(topic.id.rawValue)")
                }
            }
        }
        .scrollContentBackground(.hidden).background(AppTheme.bg)
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
                if let introduction = topic.introduction { Text(introduction) }
                if exercises.isEmpty && foundations.isEmpty {
                    Text("Тема включена в программу. Объяснения и упражнения готовятся.")
                } else {
                    Text("Охват текущих упражнений: \(progress.covered)/\(total)")
                        .accessibilityIdentifier("catalog.progress.\(topic.id.rawValue)")
                    Text("Ответов: \(progress.observations.count). Последние верные ответы: \(progress.latestCorrect)/\(progress.covered).")
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                        .accessibilityIdentifier("catalog.answers.\(topic.id.rawValue)")
                    LearningMetricsView(progress: progress, identifier: "learning.metrics.topic." + topic.id.rawValue)
                    LearningNextStepView(ids: progress.exerciseIDs)
                    Text(progress.completedAvailableExercises ? "Ответы на все доступные упражнения сохранены." : "Пройдите доступные упражнения этой темы.")
                    Text("Этот охват относится к опубликованным задачам. Полная тема может включать новые сценарии. Общие задания учитываются в каждой связанной теме по одной сохранённой попытке.")
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                    ForEach(exercises) { exercise in
                        NavigationLink {
                            LessonTemplateView(exercise: exercise, topicID: topic.id)
                        } label: {
                            VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
                                Text(exercise.title).font(.headline)
                                Text(exercise.calculation.title).font(.footnote)
                                if let latest = catalog.observations.last(where: { $0.exerciseID == exercise.id }) {
                                    Text(latest.isCorrect ? "Последний ответ: верно по условию." : "Последний ответ: есть ошибка.")
                                        .font(.footnote)
                                        .accessibilityIdentifier("catalog.latest.\(exercise.id.rawValue)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppTheme.Measure.d16).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("catalog.exercise.\(exercise.id.rawValue)")
                    }
                }
                ForEach(foundations) { exercise in
                    NavigationLink { FoundationLessonView(exercise: exercise) } label: {
                        VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
                            Text(exercise.title).font(.headline)
                            Text(exercise.purpose.title + " · " + exercise.resultKind.title).font(.footnote)
                            if let latest = catalog.observations.last(where: { $0.exerciseID == exercise.id }) {
                                Text(latest.isCorrect ? "Последний ответ: верно по условию." : "Последний ответ: есть ошибка.").font(.footnote)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppTheme.Measure.d16)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                    }.buttonStyle(.plain).accessibilityIdentifier("catalog.exercise.\(exercise.id.rawValue)")
                }
                if !topic.prerequisites.isEmpty {
                    GroupBox("Предпосылки") {
                        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                            ForEach(topic.prerequisites, id: \.self) { id in
                                if let prerequisite = CourseCatalog.topics.first(where: { $0.id == id }) {
                                    NavigationLink { CatalogTopicView(topic: prerequisite) } label: {
                                        Text("\(id.rawValue) · \(prerequisite.title)")
                                    }
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text("Редакция каталога: \(CourseCatalog.contentVersion)").font(.footnote).foregroundStyle(AppTheme.muted)
            }.padding(AppTheme.Measure.d16)
        }
        .lessonCanvas().navigationTitle(topic.id.rawValue)
    }
}


struct CatalogProgressSection: View {
    @EnvironmentObject private var store: PracticeStore
    var body: some View {
        let catalog = store.catalog
        let overall = catalog.overallProgress
        Section("Темы курса") {
            LearningMetricsView(progress: overall, identifier: "learning.metrics.total")
            LearningProjectCriterionView()
            LearningNextStepView()
            LearningReviewQueueView()
            Text("Уникальных задач: \(overall.covered)/\(overall.exerciseIDs.count). Ответов: \(overall.observations.count).")
                .accessibilityIdentifier("progress.catalog.summary")
            Text("Общие задания входят в несколько тем. В общем охвате каждая задача учитывается один раз.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            NavigationLink { CourseCatalogView() } label: {
                Label("Открыть каталог T01–T60", systemImage: "books.vertical")
            }.accessibilityIdentifier("progress.catalog")
            ForEach(CourseLevel.allCases) { level in
                DisclosureGroup(level.title) {
                    LearningMetricsView(progress: catalog.progress(in: level), identifier: "learning.metrics.level." + level.rawValue)
                    LearningNextStepView(ids: catalog.progress(in: level).exerciseIDs)
                    LearningProjectCriterionView()
                }.accessibilityIdentifier("learning.level." + level.rawValue)
            }
            ForEach(CourseCatalog.modules) { module in
                DisclosureGroup {
                    LearningMetricsView(progress: catalog.progress(in: module.id), identifier: "learning.metrics.module." + module.id.rawValue)
                    LearningNextStepView(ids: catalog.progress(in: module.id).exerciseIDs)
                    ForEach(CourseCatalog.topics.filter { $0.moduleID == module.id }) { topic in
                        let progress = catalog.progress(for: topic.id)
                        NavigationLink { CatalogTopicView(topic: topic) } label: {
                            VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
                                Text("\(topic.id.rawValue) · \(topic.title)")
                                Text(progress.exerciseIDs.isEmpty ? "Материал готовится" : "Охват: \(progress.covered)/\(progress.exerciseIDs.count) · последние верные: \(progress.latestCorrect)")
                                    .font(.footnote).foregroundStyle(AppTheme.muted)
                            }
                        }.accessibilityIdentifier("progress.topic.\(topic.id.rawValue)")
                    }
                } label: {
                    let progress = catalog.progress(in: module.id)
                    Text("\(module.id.rawValue) · \(module.title) · " + (progress.exerciseIDs.isEmpty ? "материал готовится" : "\(progress.covered)/\(progress.exerciseIDs.count)"))
                }
                .accessibilityIdentifier("progress.module.\(module.id.rawValue)")
            }
        }
    }
}

/// Always available before advanced study; the same introduction serves M01.
struct CourseBoundariesIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Text("Перед практикой").font(.headline)
                .accessibilityIdentifier("course.boundaries.introduction")
            Text("Фишки виртуальные и денежной ценности не имеют. Результат одной раздачи зависит от случайности; проверяйте решение по доступным тогда данным.")
            Text("Заранее выберите время окончания. При усталости, раздражении или желании отыграться сделайте паузу. Личный предел — основание завершить занятие.")
            Text("При повторяющихся трудностях с соблюдением границ обсудите их с человеком, которому доверяете, или квалифицированным специалистом.")
            if let topic = CourseCatalog.topics.first(where: { $0.id == .t59 }) {
                NavigationLink { CatalogTopicView(topic: topic) } label: {
                    Label("Личные границы · T59", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("course.boundaries.open")
            }
            Text("Подробный разбор риска — в M18. Эти рекомендации помогают организовать практику; ответ в упражнении проверяет знание сценария.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
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
        VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
            Text("Попыток: \(metrics.attempts) · разных шаблонов: \(metrics.distinctTemplates)")
                .accessibilityIdentifier(identifier)
            Text("Охват: \(progress.covered)/\(progress.exerciseIDs.count) заданий")
            if let accuracy = metrics.firstTemplateAccuracy {
                Text("Точность на новых шаблонах: \(metrics.firstTemplateCorrect)/\(metrics.firstTemplateAttempts) · \((accuracy * 100).formatted(.number.precision(.fractionLength(1)))) %")
            } else {
                Text("Точность на новых шаблонах: пока нет ответов")
            }
            Text("Учебные результаты учитываются по ответам на задания. Баланс виртуальных фишек ведётся отдельно.").font(.footnote).foregroundStyle(AppTheme.muted)
            Text("Новый шаблон — первый ответ по E-ID. Последующие попытки сохраняются отдельно.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            if let date = metrics.lastChecked {
                Text("Последняя проверка: " + date.formatted(date: .abbreviated, time: .shortened))
            } else { Text("Последняя проверка: ещё не было") }
            Text(metrics.projectCriterionStatus).font(.footnote).foregroundStyle(AppTheme.muted)
            if metrics.smallSample {
                Text("Малая выборка: ответы описывают только встреченные задачи. Для первичного критерия нужно 20 новых шаблонов.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
        }
        .font(.subheadline)
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

@MainActor @ViewBuilder private func learningDestination(_ id: CatalogExerciseID) -> some View {
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
