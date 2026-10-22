import Foundation
import PokerCore

private struct TopicRow: Codable {
    let id: String
    let title: String
    let module: String
    let prerequisites: [String]
    let legacyIDs: [String]
    let foundationIDs: [String]
    let status: String
}
private struct ModuleRow: Codable {
    let id: String
    let title: String
    let topics: [String]
    let uniqueTasks: Int
}
private struct Manifest: Codable {
    let contentVersion: Int
    let uniqueTasks: Int
    let legacyTasks: Int
    let foundationV2Tasks: Int
    let intermediateTasks: Int
    let advancedTasks: Int
    let topics: [TopicRow]
    let modules: [ModuleRow]
}
@main struct CourseCatalogManifest {
    static func main() throws {
        let topics = CourseCatalog.topics.map { topic in
            let old = CourseCatalog.exercises(for: topic.id).map { $0.id.rawValue }
            let new = CourseCatalog.foundations(for: topic.id).map { $0.id.rawValue }
            let published = topic.moduleID.rawValue <= "M13"
            return TopicRow(id: topic.id.rawValue, title: topic.title, module: topic.moduleID.rawValue,
                            prerequisites: topic.prerequisites.map(\.rawValue), legacyIDs: old, foundationIDs: new,
                            status: published ? "Блок доступен" : (old.isEmpty && new.isEmpty ? "Подготовка" : "Частично"))
        }
        let snapshot = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: PracticeArchive()))
        let modules = CourseCatalog.modules.map { module in
            ModuleRow(id: module.id.rawValue, title: module.title,
                      topics: topics.filter { $0.module == module.id.rawValue }.map(\.id),
                      uniqueTasks: snapshot.progress(in: module.id).exerciseIDs.count)
        }
        let value = Manifest(contentVersion: CourseCatalog.contentVersion, uniqueTasks: CourseCatalog.allExerciseIDs.count,
                             legacyTasks: CourseCatalog.exercises.count, foundationV2Tasks: FoundationLesson.v2Exercises.count,
                             intermediateTasks: FoundationLesson.intermediateExercises.count, advancedTasks: FoundationLesson.advancedExercises.count, topics: topics, modules: modules)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
    }
}
