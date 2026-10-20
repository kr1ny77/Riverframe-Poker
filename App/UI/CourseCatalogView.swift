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
                Text("60 тем · 18 модулей · 4 уровня")
                    .accessibilityIdentifier("catalog.summary")
                Text("Доступные упражнения используют уже пройденные вами наборы. У тем с частичным материалом показан охват текущих задач.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            ForEach(CourseLevel.allCases) { level in
                Section(level.title) {
                    ForEach(CourseCatalog.modules.filter { $0.level == level }) { module in
                        NavigationLink {
                            CatalogModuleView(module: module)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(module.id.rawValue) · \(module.title)")
                                Text("Тем: \(CourseCatalog.topics.filter { $0.moduleID == module.id }.count)")
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
    var body: some View {
        List {
            Section(module.title) {
                ForEach(CourseCatalog.topics.filter { $0.moduleID == module.id }) { topic in
                    NavigationLink {
                        CatalogTopicView(topic: topic)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(topic.id.rawValue) · \(topic.title)")
                            let count = CourseCatalog.exercises(for: topic.id).count
                            Text(count == 0 ? "Материал готовится" : "Доступно упражнений: \(count) · часть темы")
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

private struct CatalogTopicView: View {
    let topic: CatalogTopic
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let exercises = CourseCatalog.exercises(for: topic.id)
        let catalog = store.catalog
        let progress = catalog.progress(for: topic.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LessonHeader(title: topic.title, detail: topic.id.rawValue)
                if let error = store.errorMessage {
                    ErrorNotice(text: error)
                    Button("Повторить загрузку") { store.reload() }.buttonStyle(SecondaryButtonStyle())
                }
                if let introduction = topic.introduction { Text(introduction) }
                if exercises.isEmpty {
                    Text("Тема включена в программу. Объяснения и упражнения готовятся.")
                } else {
                    Text("Охват текущих упражнений: \(progress.covered)/\(exercises.count)")
                        .accessibilityIdentifier("catalog.progress.\(topic.id.rawValue)")
                    Text("Ответов: \(progress.observations.count). Последние верные ответы: \(progress.latestCorrect)/\(progress.covered).")
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                        .accessibilityIdentifier("catalog.answers.\(topic.id.rawValue)")
                    Text(progress.completedAvailableExercises ? "Ответы на все доступные упражнения сохранены." : "Пройдите доступные упражнения этой темы.")
                    Text("Этот охват относится к опубликованным задачам. Полная тема может включать новые сценарии. Общие задания учитываются в каждой связанной теме по одной сохранённой попытке.")
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                    if topic.id == .t11 {
                        GroupBox("Термин") { Text("Pot odds — минимальная средняя доля итогового банка для оплаты колла при заданных условиях.") }
                        GroupBox("Метод") { Text("Для pot odds применяется точная арифметика цены колла и итогового банка. Для EV ривера полностью проверяются заданные руки с весами; диапазон является условной моделью.") }
                    }
                    ForEach(exercises) { exercise in
                        NavigationLink {
                            CatalogExerciseView(exercise: exercise)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(exercise.title).font(.headline)
                                Text(exercise.calculation.title).font(.footnote)
                                if let latest = catalog.observations.last(where: { $0.exerciseID == exercise.id }) {
                                    Text(latest.isCorrect ? "Последний ответ: верно по условию." : "Последний ответ: есть ошибка.")
                                        .font(.footnote)
                                        .accessibilityIdentifier("catalog.latest.\(exercise.id.rawValue)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("catalog.exercise.\(exercise.id.rawValue)")
                    }
                }
                if !topic.prerequisites.isEmpty {
                    GroupBox("Предпосылки") {
                        Text(topic.prerequisites.map(\.rawValue).joined(separator: ", "))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text("Редакция каталога: \(CourseCatalog.contentVersion)").font(.footnote).foregroundStyle(AppTheme.muted)
            }.padding(16)
        }
        .lessonCanvas().navigationTitle(topic.id.rawValue)
    }
}

private struct CatalogExerciseView: View {
    let exercise: CatalogExercise
    var body: some View {
        if let question = exercise.potOddsQuestion {
            PotOddsExerciseView(question: question)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LessonHeader(title: exercise.title, detail: exercise.calculation.title)
                    Text("Это упражнение входит в набор «\(exercise.lesson.title)». Набор открывается целиком и сохраняет результаты каждого ответа отдельно.")
                    NavigationLink {
                        CourseLessonDestination(lesson: exercise.lesson)
                    } label: {
                        Text("Открыть набор")
                    }.buttonStyle(PrimaryButtonStyle())
                    Text("Редакция упражнения: \(exercise.contentVersion)").font(.footnote).foregroundStyle(AppTheme.muted)
                }.padding(16)
            }.lessonCanvas().navigationTitle("Упражнение")
        }
    }
}
