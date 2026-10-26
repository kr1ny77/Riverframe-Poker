import Foundation
import Testing
@testable import PokerCore

private func completeCourseArchive() throws -> PracticeArchive {
    var archive=PracticeArchive()
    archive.attempts=PotOddsQuestion.examples.map { PracticeAttempt(question:$0,answer:$0.correctPercent) }
    archive.attempts += FlushDrawLesson.standard.questions.map { PracticeAttempt(question:$0,answer:$0.correctPercent) }
    for q in KnownHandEquityQuestion.examples { archive.attempts.append(PracticeAttempt(question:q,result:try q.calculate(),answer:try q.calculate().equityPercent)) }
    for q in RangeEquityQuestion.examples { archive.attempts.append(PracticeAttempt(question:q,result:try q.calculate(),answer:try q.calculate().equityPercent)) }
    archive.comparisons=HandComparisonLesson.questions(seed:17).map { HandComparisonAttempt(question:$0,answer:$0.mode == .winner ? .winner($0.winner) : .bestFive($0.bestFive)) }
    archive.positions=try PositionLesson.questions.map { try PositionAttempt(question:$0,answerIndex:$0.correctIndex) }
    archive.evCalls=try EVCallQuestion.examples.map { try EVCallAttempt(question:$0,decision:$0.result.accepts(.call) ? .call : .fold) }
    archive.blockers=try BlockerQuestion.examples.map { try BlockerAttempt(questionID:$0.id,answerIndex:$0.correctIndex!) }
    return archive
}

@Test func courseCatalogPrerequisitesAndFullCoverage() throws {
    #expect(CourseLessonID.allCases.map { $0.requiredKeys.count } == [12,2,3,2,12,3,3,6])
    #expect(CourseLessonID.allCases.reduce(0) { $0+$1.requiredKeys.count } == 43)
    #expect(LearningCourseSnapshot(archive:PracticeArchive()).nextLesson == .combinations)
    for (index,lesson) in CourseLessonID.allCases.enumerated() {
        #expect(lesson.prerequisites.allSatisfy { CourseLessonID.allCases.firstIndex(of:$0)! < index })
    }
    let all=try completeCourseArchive()
    let full=LearningCourseSnapshot(archive:all)
    #expect(full.observations.count == 43 && full.ignoredRecords == 0)
    #expect(full.completedLessons == 8 && full.nextLesson == nil && full.repeatLessons.isEmpty)
    #expect(CourseLessonID.allCases.allSatisfy { full.progress($0).completed && full.progress($0).latestCorrect == $0.requiredKeys.count })
    var prefix=PracticeArchive()
    for (index,lesson) in CourseLessonID.allCases.enumerated() {
        #expect(LearningCourseSnapshot(archive:prefix).nextLesson == lesson)
        switch lesson {
        case .combinations:prefix.comparisons=all.comparisons
        case .outs:prefix.attempts += all.attempts.filter { $0.topic == .outs }
        case .potOdds:prefix.attempts += all.attempts.filter { $0.topic == .potOdds }
        case .knownEquity:prefix.attempts += all.attempts.filter { $0.topic == .knownHandEquity }
        case .positions:prefix.positions=all.positions
        case .rangeEquity:prefix.attempts += all.attempts.filter { $0.topic == .rangeEquity }
        case .evCall:prefix.evCalls=all.evCalls
        case .blockers:prefix.blockers=all.blockers
        }
        #expect(LearningCourseSnapshot(archive:prefix).completedLessons == index+1)
    }
}

@Test func courseUniqueTemplatesLatestGradesAndPersistence() throws {
    var archive=try completeCourseArchive()
    archive.comparisons += HandComparisonLesson.questions(seed:28).map { HandComparisonAttempt(question:$0,answer:$0.mode == .winner ? .winner($0.winner) : .bestFive($0.bestFive)) }
    archive.attempts.append(PracticeAttempt(question:PotOddsQuestion.examples[0],answer:0))
    let course=LearningCourseSnapshot(archive:archive)
    #expect(course.progress(.combinations).covered == 12 && course.progress(.combinations).observations.count == 24)
    #expect(course.progress(.potOdds).completed && course.progress(.potOdds).latestCorrect == 2)
    #expect(!course.progress(.potOdds).repeatRecommended) // Four answers do not imply a weakness.
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let history=PracticeHistory(fileURL:directory.appendingPathComponent("history.json"))
    try history.saveArchive(archive)
    let restored=LearningCourseSnapshot(archive:try history.loadArchive())
    #expect(restored.completedLessons == 8 && restored.observations.count == course.observations.count)
    #expect(restored.progress(.potOdds).latestCorrect == 2)
    var duplicate=archive;duplicate.attempts.append(archive.attempts[0])
    #expect(LearningCourseSnapshot(archive:duplicate).ignoredRecords == 1)
}

@Test func courseRepeatThresholdsAndRecentWindow() {
    func progress(count:Int,errors:Int,distinct:Int) -> CourseLessonProgress {
        let observations=(0..<count).map { i in CourseObservation(id:UUID(),date:Date(timeIntervalSince1970:Double(i)),lesson:.potOdds,key:PotOddsQuestion.examples[i%distinct].id,category:.potPrice,isCorrect:i>=errors) }
        return CourseLessonProgress(lesson:.potOdds,observations:observations)
    }
    #expect(!progress(count:9,errors:3,distinct:3).repeatRecommended)
    #expect(progress(count:10,errors:3,distinct:3).repeatRecommended)
    #expect(!progress(count:10,errors:2,distinct:3).repeatRecommended)
    #expect(!progress(count:20,errors:5,distinct:3).repeatRecommended)
    #expect(progress(count:20,errors:6,distinct:3).repeatRecommended)
    #expect(!progress(count:100,errors:100,distinct:1).repeatRecommended)
    let repaired=progress(count:40,errors:20,distinct:3)
    #expect(repaired.recent.count == 20 && repaired.recentErrors == 0 && !repaired.repeatRecommended)
    #expect(repaired.completed && repaired.latestCorrect == 3)
}

@Test func courseTaxonomyAndUnknownNumericIntegrity() throws {
    var archive=PracticeArchive()
    archive.attempts=[PracticeAttempt(question:PotOddsQuestion.examples[0],answer:0),PracticeAttempt(question:FlushDrawLesson.standard.questions[1],answer:0)]
    archive.positions=[try PositionAttempt(question:PositionLesson.questions[0],answerIndex:1),try PositionAttempt(question:PositionLesson.questions[6],answerIndex:1)]
    archive.evCalls=[try EVCallAttempt(question:EVCallQuestion.examples[1],decision:.call)]
    archive.blockers=[try BlockerAttempt(questionID:BlockerQuestion.examples[4].id,answerIndex:1)]
    let course=LearningCourseSnapshot(archive:archive)
    #expect(Set(course.observations.map(\.category)) == [.potPrice,.byRiver,.seat,.actionOrder,.evComparison,.conditionalWeights])
    #expect(course.progress(.potOdds).errors.first?.answers == 1 && course.progress(.potOdds).errors.first?.errors == 1)
    archive.attempts.append(PracticeAttempt(questionID:"unknown-v1",answer:0,expectedPercent:0))
    archive.attempts.append(PracticeAttempt(questionID:PotOddsQuestion.examples[1].id,answer:0,expectedPercent:0))
    let guarded=LearningCourseSnapshot(archive:archive)
    #expect(guarded.ignoredRecords == 2 && guarded.observations.count == course.observations.count)
    #expect(archive.attempts.count == 4) // Analysis leaves stored history intact.
    let original=HandComparisonLesson.questions(seed:7)[0]
    let falseKey=original.id.contains("-wheel-") ? "pair" : "wheel"
    let fingerprint=(original.first+original.second+original.board).map { String($0.id) }.joined(separator:".")
    let forged=try HandComparisonQuestion(id:"hcmp-v1-\(falseKey)-\(original.mode.rawValue)-\(fingerprint)",first:original.first,second:original.second,board:original.board,mode:original.mode)
    let attempt=HandComparisonAttempt(question:forged,answer:forged.mode == .winner ? .winner(forged.winner) : .bestFive(forged.bestFive))
    #expect(attempt.isValid)
    #expect(LearningCourseSnapshot(archive:PracticeArchive(comparisons:[attempt])).ignoredRecords == 1)
}

@Test func courseWheelErrorRetainsItsSpecificCategory() throws {
    let question=try #require(HandComparisonLesson.questions(seed:7).first { $0.id.contains("-wheel-") })
    let cards=question.first+question.board
    var incorrect:[Card]?
    for a in 0..<7 {
        for b in (a+1)..<7 {
            let candidate=cards.enumerated().filter { $0.offset != a && $0.offset != b }.map(\.element)
            if !question.isCorrect(.bestFive(candidate)) { incorrect=candidate;break }
        }
        if incorrect != nil { break }
    }
    let attempt=HandComparisonAttempt(question:question,answer:.bestFive(try #require(incorrect)))
    #expect(attempt.isValid && !attempt.isCorrect)
    let course=LearningCourseSnapshot(archive:PracticeArchive(comparisons:[attempt]))
    #expect(course.progress(.combinations).errors.first?.category == .wheel)
}

@Test func courseAccuracyDenominatorsAndTopicIsolation() throws {
    var archive=PracticeArchive()
    // Pot odds: first task wrong then corrected, second correct, third wrong.
    // Four answers, two correct; latest answers cover three tasks, two correct.
    for (index,answer) in [(0,0.0),(0,25.0),(1,100.0/3),(2,0.0)] {
        archive.attempts.append(PracticeAttempt(question:PotOddsQuestion.examples[index],answer:answer))
    }
    archive.attempts.append(PracticeAttempt(question:FlushDrawLesson.standard.questions[0],answer:0))
    var timed=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(archive.attempts)) as? [[String:Any]])
    for index in timed.indices { timed[index]["date"]=Double(index) }
    archive.attempts=try JSONDecoder().decode([PracticeAttempt].self,from:JSONSerialization.data(withJSONObject:timed))
    let snapshot=LearningCourseSnapshot(archive:archive)
    let pot=snapshot.progress(.potOdds),outs=snapshot.progress(.outs)
    #expect(pot.observations.count == 4 && pot.observations.filter(\.isCorrect).count == 2)
    #expect(pot.covered == 3 && pot.latestCorrect == 2 && pot.completed)
    #expect(pot.recentErrors == 2 && pot.errors.first?.answers == 4)
    #expect(outs.covered == 1 && outs.latestCorrect == 0 && outs.recentErrors == 1)
    #expect(!pot.repeatRecommended && !outs.repeatRecommended)
    #expect(pot.repeatText.contains("больше ответов") && pot.sampleText.contains("4 ответов · 3 разных заданий"))
    // Reverse physical archive order; timestamps still determine latest grades.
    archive.attempts.reverse()
    #expect(LearningCourseSnapshot(archive:archive).progress(.potOdds).latestCorrect == 2)
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let history=PracticeHistory(fileURL:directory.appendingPathComponent("audit.json"))
    try history.saveArchive(archive)
    let loaded=try history.loadArchive()
    #expect(loaded.attempts == archive.attempts && loaded.comparisons == archive.comparisons
        && loaded.positions == archive.positions && loaded.evCalls == archive.evCalls
        && loaded.blockers == archive.blockers && loaded.foundations == archive.foundations)
    #expect(loaded.diagnostics == CourseLearning.inferredDiagnostics(catalog: CourseCatalogSnapshot(
        course: LearningCourseSnapshot(archive: archive), foundations: archive.foundations)))
    let restored=LearningCourseSnapshot(archive:loaded).progress(.potOdds)
    #expect(restored.latestCorrect == 2 && restored.recentErrors == 2 && restored.covered == 3)
}

@Test func courseTwoTaskSampleAndRepeatAfterCompletion() throws {
    let questions=FlushDrawLesson.standard.questions
    var partial=PracticeArchive(attempts:(0..<10).map { PracticeAttempt(question:questions[$0%2],answer:0) })
    let progress=LearningCourseSnapshot(archive:partial).progress(.outs)
    #expect(progress.repeatRecommended && progress.recentDistinct == 2)
    partial.attempts=Array(partial.attempts.prefix(9))
    #expect(!LearningCourseSnapshot(archive:partial).progress(.outs).repeatRecommended)
    var full=try completeCourseArchive()
    full.attempts += (0..<12).map { PracticeAttempt(question:PotOddsQuestion.examples[$0%3],answer:0) }
    let course=LearningCourseSnapshot(archive:full)
    #expect(course.completedLessons == 8 && course.nextLesson == .potOdds)
    #expect(course.repeatLessons == [.potOdds])
    #expect(course.progress(.potOdds).latestCorrect == 0)
    #expect(course.progress(.potOdds).repeatText.contains("учебная эвристика"))
}

@Test func courseEqualDatesPreserveRecordedOrder() throws {
    let q=PotOddsQuestion.examples[0]
    let wrong=PracticeAttempt(question:q,answer:0),right=PracticeAttempt(question:q,answer:q.correctPercent)
    var rows=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode([wrong,right])) as? [[String:Any]])
    for index in rows.indices { rows[index]["date"]=0 }
    rows[0]["id"]="FFFFFFFF-FFFF-4FFF-8FFF-FFFFFFFFFFFF"
    rows[1]["id"]="00000000-0000-4000-8000-000000000000"
    let attempts=try JSONDecoder().decode([PracticeAttempt].self,from:JSONSerialization.data(withJSONObject:rows))
    let archive=PracticeArchive(attempts:attempts)
    let progress=LearningCourseSnapshot(archive:archive).progress(.potOdds)
    #expect(progress.latestCorrect == 1)
    #expect(progress.observations.map(\.id) == attempts.map(\.id))
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let history=PracticeHistory(fileURL:directory.appendingPathComponent("same-time.json"))
    try history.saveArchive(archive)
    #expect(LearningCourseSnapshot(archive:try history.loadArchive()).progress(.potOdds).latestCorrect == 1)
}
