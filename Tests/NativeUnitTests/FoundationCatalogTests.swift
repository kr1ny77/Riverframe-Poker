import Foundation
import Testing
@testable import PokerCore

@Test func publishedFoundationModulesPreserveAliasesAndAddAllThreeLearningPurposes() throws {
    let expected: [CourseTopicID: Int] = [.t03: 6, .t04: 6, .t05: 5, .t06: 3, .t07: 3, .t08: 3, .t09: 3, .t21: 3, .t22: 4, .t28: 3]
    #expect(FoundationLesson.exercises.count == 39)
    #expect(CourseCatalog.exercises.count == 43)
    #expect(CourseCatalog.allExerciseIDs.count == 82)
    #expect(Set(FoundationLesson.exercises.map(\.id)).isDisjoint(with: Set(CourseCatalog.exercises.map(\.id))))
    for (topic, count) in expected {
        let exercises = CourseCatalog.foundations(for: topic)
        #expect(exercises.count == count)
        #expect(Set(exercises.map(\.purpose)) == Set(FoundationPurpose.allCases))
        for exercise in exercises {
            #expect(exercise.contentVersion == 1)
            #expect(exercise.answer.correctResponse.isValid)
            #expect(exercise.answer.accepts(exercise.answer.correctResponse))
            #expect(FoundationAttempt(exercise: exercise, response: exercise.answer.correctResponse).isValid)
            #expect(CourseCatalog.topics.contains { $0.id == topic })
        }
    }
    let empty = CourseCatalogSnapshot(course: LearningCourseSnapshot(archive: PracticeArchive()))
    #expect(empty.progress(in: .m01).exerciseIDs.count == 38)
    #expect(empty.progress(in: .m02).exerciseIDs.count == 11)
    #expect(empty.progress(in: .m03).exerciseIDs.count == 17)
    #expect(empty.progress(in: .m04).exerciseIDs.count == 13)
    #expect(CourseCatalog.exercises(for: .t11).count == 6)
    #expect(CourseCatalog.foundations(for: .t11).isEmpty)
}

@Test func foundationCoverageUsesCurrentRevisionAndChronologicalLatestWithoutChangingLegacyCompletion() throws {
    let attempts = FoundationLesson.exercises.enumerated().map { index, exercise in
        FoundationAttempt(exercise: exercise, response: exercise.answer.correctResponse,
                          date: Date(timeIntervalSinceReferenceDate: Double(index)))
    }
    let first = try #require(FoundationLesson.exercises.first)
    let wrong = FoundationAttempt(exercise: first, response: .number(-100), date: Date(timeIntervalSinceReferenceDate: 999))
    let pot = PracticeAttempt(question: PotOddsQuestion.examples[0], answer: 25)
    let archive = PracticeArchive(attempts: [pot], foundations: attempts + [wrong])
    let oldCourse = LearningCourseSnapshot(archive: archive)
    #expect(oldCourse.completedLessons == 0)
    #expect(oldCourse.observations.count == 1)
    let snapshot = CourseCatalogSnapshot(course: oldCourse, foundations: archive.foundations.reversed())
    #expect(snapshot.observations.count == 41)
    #expect(snapshot.overallProgress.covered == 40)
    #expect(snapshot.overallProgress.latestCorrect == 39)
    #expect(snapshot.progress(for: .t03).completedAvailableExercises)
    #expect(snapshot.progress(for: .t03).latestCorrect == 5)
    #expect(snapshot.observations.last(where: { $0.exerciseID == first.id })?.id == wrong.id)
}
