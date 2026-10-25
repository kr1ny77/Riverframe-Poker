import SwiftUI
import PokerCore

struct LearningCourseHomeView: View {
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let course = store.course
        let totalTasks = CourseCatalog.allExerciseIDs.count
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LessonHeader(title: "Курс NLHE", detail: "60 тем · 18 модулей · 4 уровня")

                if let error = store.errorMessage {
                    ErrorNotice(text: error)
                    Button("Повторить загрузку") { store.reload() }
                        .buttonStyle(SecondaryButtonStyle())
                }

                Text("Пройдено наборов: \(course.completedLessons) из \(CourseLessonID.allCases.count)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityIdentifier("course.completed")

                NavigationLink {
                    CourseCatalogView()
                } label: {
                    Label("Каталог: 60 тем", systemImage: "books.vertical")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("course.catalog")

                Text("Опубликовано \(totalTasks) разных задач. История прежних наборов входит в охват тем.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                CourseBoundariesIntroduction()
                CourseNextStepView()

                if !course.repeatLessons.isEmpty {
                    courseSection(title: "Повторить по ответам", detail: "Задания с достаточным числом ошибок") {
                        ForEach(course.repeatLessons, id: \.self) { lesson in
                            NavigationLink(value: lesson) {
                                CourseLessonRow(lesson: lesson, course: course, subtitle: course.progress(lesson).repeatText)
                            }
                            .accessibilityIdentifier("course.repeat.\(lesson.rawValue)")
                        }
                    }
                }

                courseSection(title: "Маршрут курса", detail: "Все темы доступны. Порядок помогает наращивать опору.") {
                    ForEach(CourseStage.allCases) { stage in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(stage.title).font(.headline).foregroundStyle(AppTheme.text)
                            ForEach(CourseLessonID.allCases.filter { $0.stage == stage }) { lesson in
                                let progress = course.progress(lesson)
                                NavigationLink(value: lesson) {
                                    CourseLessonRow(
                                        lesson: lesson,
                                        course: course,
                                        subtitle: "\(progress.completed ? "Набор пройден" : "Задания") · \(progress.covered)/\(lesson.requiredKeys.count) · последние ответы: \(progress.latestCorrect)/\(progress.covered)"
                                    )
                                }
                                .accessibilityIdentifier(lesson.accessibilityID)
                            }
                        }
                    }
                }

                DisclosureGroup("Предпосылки уроков") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(CourseLessonID.allCases) { lesson in
                            let prerequisites = lesson.prerequisites
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lesson.title).font(.subheadline.weight(.semibold))
                                if prerequisites.isEmpty {
                                    Text("Вводный урок. Его можно открыть сразу.")
                                } else {
                                    Text("Рекомендуется после: " + prerequisites.map { prerequisite in
                                        "\(prerequisite.title) — \(course.progress(prerequisite).completed ? "пройдено" : "впереди")"
                                    }.joined(separator: "; ") + ".")
                                }
                            }
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                }

                DisclosureGroup("Как читать прогресс") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LearningCourseSnapshot.interpretation)
                        Text("Охват показывает число разных задач. Последний ответ показывает текущий результат по уже встреченным задачам.")
                        Text("Рекомендация повтора появляется после накопления ответов. Она помогает выбрать следующий шаг и не описывает уровень игры целиком.")
                    }
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                }

                DisclosureGroup("Статус учебных моделей") {
                    Text("Все 60 тем доступны. Арифметика проверяет заданные входы; стратегические примеры используют условные диапазоны. Учебные solver-отчёты показывают способ чтения и проверки модели. Турнирные выплаты разбираются в отдельных задачах; практика проходит за столом 6-max.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(16)
        }
        .lessonCanvas()
        .navigationTitle("Тренировка")
        .navigationDestination(for: CourseLessonID.self) { CourseLessonDestination(lesson: $0) }
    }

    @ViewBuilder
    private func courseSection<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(AppTheme.muted).fixedSize(horizontal:false,vertical:true)
            content()
        }
        .padding(16)
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
        let course = store.course
        VStack(alignment: .leading, spacing: 10) {
            if let next = course.nextLesson {
                Label(course.progress(next).completed ? "Повторение по накопленным ответам" : "Следующий урок", systemImage: "arrow.right.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                NavigationLink(value: next) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(next.title).font(.title3.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
                                .multilineTextAlignment(.leading)
                            Text(course.progress(next).completed ? "Вернитесь к задачам, где накопились ошибки." : "Откройте урок и решите следующую задачу.")
                                .font(.footnote)
                                .fixedSize(horizontal:false,vertical:true)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        if !embeddedInList { Image(systemName: "arrow.right").fontWeight(.semibold) }
                    }
                }
                .accessibilityIdentifier("course.next")
            } else {
                Label("Все доступные наборы пройдены", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.success)
                Text("Для переноса навыка нужны новые задачи и отложенная проверка.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(16)
        .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: AppTheme.radius))
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
