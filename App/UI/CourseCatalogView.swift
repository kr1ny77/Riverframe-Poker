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
                Text("Доступные упражнения используют прежние наборы и сохранённую историю. У тем с частичным материалом показан охват текущих задач.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            ForEach(CourseLevel.allCases) { level in
                Section(level.title) {
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
    var body: some View {
        List {
            Section(module.title) {
                ForEach(CourseCatalog.topics.filter { $0.moduleID == module.id }) { topic in
                    NavigationLink {
                        CatalogTopicView(topic: topic)
                    } label: {
                        VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
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

struct CatalogTopicView: View {
    let topic: CatalogTopic
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let exercises = CourseCatalog.exercises(for: topic.id)
        let catalog = store.catalog
        let progress = catalog.progress(for: topic.id)
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d18) {
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
            Text("Уникальных задач: \(overall.covered)/\(overall.exerciseIDs.count). Ответов: \(overall.observations.count).")
                .accessibilityIdentifier("progress.catalog.summary")
            Text("Общие задания входят в несколько тем. В общем охвате каждая задача учитывается один раз.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            NavigationLink { CourseCatalogView() } label: {
                Label("Открыть каталог T01–T60", systemImage: "books.vertical")
            }.accessibilityIdentifier("progress.catalog")
            ForEach(CourseCatalog.modules) { module in
                DisclosureGroup {
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
