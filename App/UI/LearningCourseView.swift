import SwiftUI
import PokerCore

struct LearningCourseHomeView: View {
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let course = store.course
        let totalTasks = CourseCatalog.allExerciseIDs.count
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d20) {
                LessonHeader(title: "Тренировка", detail: "Курс, задачи и повторение")

                if let error = store.errorMessage {
                    ErrorNotice(text: error)
                    Button("Повторить загрузку") { store.reload() }
                        .buttonStyle(SecondaryButtonStyle())
                }

                CourseNextStepView()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppTheme.Measure.d12) {
                        NavigationLink { CourseCatalogView() } label: {
                            Label("Открыть каталог", systemImage: "rectangle.grid.2x2")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("course.catalog")
                        LearningCatalogHint(totalTasks: totalTasks)
                    }
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                        NavigationLink { CourseCatalogView() } label: {
                            Label("Открыть каталог T01–T60", systemImage: "rectangle.grid.2x2")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("course.catalog")
                        LearningCatalogHint(totalTasks: totalTasks)
                    }
                }

                Text("60 тем · 18 модулей · 4 уровня").font(.subheadline).foregroundStyle(AppTheme.muted)
                Text("Пройдено прежних наборов: \(course.completedLessons) из \(CourseLessonID.allCases.count)").font(.footnote).foregroundStyle(AppTheme.muted).accessibilityIdentifier("course.completed")
                WorkbenchCourseDetails(course: course)
            }
            .padding(AppTheme.Measure.d16)
            .padding(.bottom, AppTheme.Measure.d16)
        }
        .lessonCanvas()
        .navigationTitle("Тренировка")
        .navigationDestination(for: CourseLessonID.self) { CourseLessonDestination(lesson: $0) }
    }

    private func courseWorkspaceOverview(course: LearningCourseSnapshot, totalTasks: Int) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Label("Рабочая карта", systemImage: "map")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Measure.d16) {
                    courseMetric("Темы", value: "60")
                    courseMetric("Модули", value: "18")
                    courseMetric("Уровни", value: "4")
                    courseMetric("Задачи", value: "\(totalTasks)")
                }
                VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                    Text("60 тем · 18 модулей · 4 уровня · \(totalTasks) задач")
                        .font(.subheadline.weight(.semibold))
                }
            }
            Text("Пройдено прежних наборов: \(course.completedLessons) из \(CourseLessonID.allCases.count)")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .accessibilityIdentifier("course.completed")
        }
        .padding(AppTheme.Measure.d16)
        .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: AppTheme.radius))
    }

    private func courseMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d2) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LearningCatalogHint: View {
    let totalTasks: Int

    var body: some View {
        Text("\(totalTasks) задач · старая история уже в охвате")
            .font(.footnote)
            .foregroundStyle(AppTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct WorkbenchCourseDetails: View {
    let course: LearningCourseSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            CourseBoundariesIntroduction()

            DisclosureGroup("Следующая задача и повторение") {
                VStack(alignment: .leading, spacing: AppTheme.Measure.d16) {
                    LearningNextStepView()
                    LearningReviewQueueView()
                    if !course.repeatLessons.isEmpty {
                        Divider()
                        Text("Наборы с накопившимися ошибками").font(.subheadline.weight(.semibold))
                        ForEach(course.repeatLessons, id: \.self) { lesson in
                            NavigationLink(value: lesson) {
                                CourseLessonRow(lesson: lesson, course: course, subtitle: course.progress(lesson).repeatText)
                            }
                            .accessibilityIdentifier("course.repeat.\(lesson.rawValue)")
                        }
                    }
                }
                .padding(.top, AppTheme.Measure.d8)
            }

            DisclosureGroup("Прежние восемь наборов") {
                VStack(alignment: .leading, spacing: AppTheme.Measure.d16) {
                    ForEach(CourseStage.allCases) { stage in
                        VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                            Text(stage.title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.text)
                            ForEach(CourseLessonID.allCases.filter { $0.stage == stage }) { lesson in
                                let progress = course.progress(lesson)
                                NavigationLink(value: lesson) {
                                    CourseLessonRow(
                                        lesson: lesson,
                                        course: course,
                                        subtitle: "\(progress.completed ? "Набор пройден" : "Задания") · \(progress.covered)/\(lesson.requiredKeys.count) · последние \(progress.latestCorrect)/\(progress.covered)"
                                    )
                                }
                                .accessibilityIdentifier(lesson.accessibilityID)
                            }
                        }
                    }
                }
                .padding(.top, AppTheme.Measure.d8)
            }

            DisclosureGroup("Опора и ограничения") {
                VStack(alignment: .leading, spacing: AppTheme.Measure.d8) {
                    Text(LearningCourseSnapshot.interpretation)
                    Text("Охват показывает разные задачи; последний ответ отражает текущий результат по уже встреченным задачам.")
                    Text("Арифметика проверяет заданные входы. Стратегические примеры используют условные диапазоны. Турнирные выплаты доступны только в учебных сценариях; практика проходит за столом 6-max.")
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

private struct CourseLessonRow: View {
    let lesson: CourseLessonID
    let course: LearningCourseSnapshot
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: course.progress(lesson).completed ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(course.progress(lesson).completed ? AppTheme.success : AppTheme.muted)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(.headline).foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityIdentifier("course.status.\(lesson.rawValue)")
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

struct CourseNextStepView: View {
    @EnvironmentObject private var store: PracticeStore
    var embeddedInList = false
    var body: some View {
        let learning = store.learning()
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            if let id = learning.recommendation(in: CourseCatalog.allExerciseIDs) {
                let title = FoundationLesson.exercise(id)?.title ?? CourseCatalog.exercises.first(where: { $0.id == id })?.title ?? "Открыть задачу"
                Text("Следующее решение").font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted)
                NavigationLink { learningDestination(id) } label: {
                    NavigationRow(title: title, subtitle: "Продолжить с сохранённого шага", symbol: "arrow.right.circle")
                }.buttonStyle(.plain).accessibilityIdentifier("course.next")
            } else {
                Label("Все доступные шаблоны встречались", systemImage: "checkmark.circle").font(.headline)
                Text("Откройте повторение или вернитесь к разбору.").font(.subheadline).foregroundStyle(AppTheme.muted)
            }
        }
        .padding(AppTheme.Measure.d20)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
    }
}

struct CourseFinishView: View {
    let lesson: CourseLessonID
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let progress = store.course.progress(lesson)
        VStack(alignment: .leading, spacing: 10) {
            Text("Результат набора").font(.headline)
            MetricStrip(items: [("Охват", "\(progress.covered)/\(lesson.requiredKeys.count)"), ("Последние", "\(progress.latestCorrect)/\(progress.covered)")])
            Text(progress.sampleText).font(.footnote).foregroundStyle(AppTheme.muted)
            Text(progress.repeatText).font(.footnote).foregroundStyle(AppTheme.muted)
            CourseNextStepView()
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
    }
}

struct CourseProgressSection: View {
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let course = store.course
        Section("Курс и повторение") {
            Text("Пройдено наборов: \(course.completedLessons) из \(CourseLessonID.allCases.count)")
                .font(.headline)
                .accessibilityIdentifier("course.progress.completed")
            if !course.repeatLessons.isEmpty { Text("Тем к повторению: \(course.repeatLessons.count)").foregroundStyle(AppTheme.muted) }
            CourseNextStepView(embeddedInList:true)
            Text("Прогресс отражает ответы на учебные задачи. Результат раздачи и число виртуальных фишек в эту оценку не входят.")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)

            ForEach(CourseLessonID.allCases.filter { !course.progress($0).observations.isEmpty }) { lesson in
                let progress = course.progress(lesson)
                DisclosureGroup(lesson.title) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(progress.sampleText)
                        Text(progress.repeatText).accessibilityIdentifier("course.sample.\(lesson.rawValue)")
                        Text("Последние ответы на разные задания: \(progress.latestCorrect) верных из \(progress.covered). Охват считается по разным заданиям; повтор обновляет последнюю оценку и статистику ответов.")
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                        CourseResponseHistory(progress: progress)
                        ForEach(progress.errors) { error in
                            Label("\(error.category.title): \(error.errors) ошибок из \(error.answers) ответов; \(error.distinctTasks) разных заданий.", systemImage: "exclamationmark.circle")
                                .font(.footnote).foregroundStyle(AppTheme.warning)
                                .accessibilityIdentifier("course.error.\(error.category.rawValue)")
                        }
                        if progress.repeatRecommended {
                            NavigationLink("Повторить: \(lesson.title)", value: lesson)
                                .accessibilityIdentifier("course.repeat.\(lesson.rawValue)")
                        }
                    }
                }
            }

            DisclosureGroup("Как работает повтор") {
                Text("Категория ошибки обозначает задачу с неверным ответом. Причину ошибки нужно разбирать отдельно. Повтор учитывает последние 20 ответов: минимум 10 ответов, 3 разных задания либо весь меньший набор, 3 ошибки и долю ошибок от 30%. Это продуктовая эвристика.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            if course.ignoredRecords > 0 {
                Text("За пределами каталога курса: \(course.ignoredRecords) записей. Исходная история сохранена.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
        }
    }
}

private struct CourseResponseHistory: View {
    let progress: CourseLessonProgress

    private var minimumDistinct: Int { min(3, progress.lesson.requiredKeys.count) }
    private var canShowHistory: Bool {
        progress.observations.count >= 20 && progress.covered >= minimumDistinct
    }

    var body: some View {
        if canShowHistory {
            let window = Array(progress.observations.suffix(20))
            VStack(alignment: .leading, spacing: 6) {
                Text("Последние 20 ответов на фиксированные задачи")
                    .font(.footnote.weight(.medium))
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:4),count:10),spacing:4) {
                    ForEach(Array(window.enumerated()),id:\.offset) { item in
                        Image(systemName:item.element.isCorrect ? "checkmark" : "xmark")
                            .font(.caption2.weight(.bold)).frame(maxWidth:.infinity,minHeight:24)
                            .foregroundStyle(item.element.isCorrect ? AppTheme.success : AppTheme.warning)
                            .background(AppTheme.surfaceAlt,in:RoundedRectangle(cornerRadius:4))
                            .accessibilityLabel("Ответ \(item.offset+1): \(item.element.isCorrect ? "верно" : "ошибка")")
                    }
                }
                Text("Всего ответов: \(progress.observations.count). Разных задач: \(progress.covered). Это история фиксированных задач; перенос навыка проверяется на новых ситуациях.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal:false,vertical:true)
            }
            .accessibilityElement(children: .contain)
        } else {
            Text("N = \(progress.observations.count), K = \(progress.covered). Соберите не менее 20 ответов и \(minimumDistinct) разных задач, чтобы увидеть историю этой темы.")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
    }
}

struct CourseLessonDestination: View {
    let lesson: CourseLessonID
    var body: some View {
        switch lesson {
        case .combinations: HandComparisonLessonView()
        case .outs: OutsLessonView()
        case .potOdds: PotOddsLessonView()
        case .knownEquity: EquityLessonView()
        case .positions: PositionLessonView()
        case .rangeEquity: RangeEquityLessonView()
        case .evCall: EVCallLessonView()
        case .blockers: BlockerLessonView()
        }
    }
}

struct PotOddsLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var finished = false

    var body: some View {
        if finished {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LessonHeader(title: "Набор завершён", detail: "Шансы банка · три сценария")
                    Text("Три сценария: пороги 25%, 33,33% и 16,67%. Каждый ответ относится к заданному банку и цене колла.")
                    CourseFinishView(lesson: .potOdds)
                    Button("К темам") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                }
                .padding(16)
            }
            .lessonCanvas()
        } else {
            PotOddsExerciseView(question: PotOddsQuestion.examples[index], onContinue: {
                if index + 1 == PotOddsQuestion.examples.count { finished = true } else { index += 1 }
            })
            .id(index)
        }
    }
}
