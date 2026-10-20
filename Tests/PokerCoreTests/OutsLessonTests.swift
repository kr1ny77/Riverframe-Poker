import Foundation
@testable import PokerCore

final class OutsLessonTests: CoreCheckCase {
    func testKnownCardsAndOuts() {
        let lesson=FlushDrawLesson.standard
        assertEqual(Set(lesson.hero+lesson.flop).count,5)
        assertEqual(lesson.hero.map(\.rank),[14,13])
        assertEqual(lesson.flop.map(\.rank),[12,7,2])
        assertEqual(lesson.available.count,47)
        assertEqual(lesson.outs.count,9)
        assertTrue(lesson.outs.allSatisfy { $0.suit==1 })
        assertTrue(Set(lesson.outs).isDisjoint(with:lesson.hero+lesson.flop))
        assertEqual(Set(lesson.outs.map(\.rank)),Set([2,3,4,5,6,8,9,10,11]))
    }
    func testExactCountsMatchHypergeometricFormula() {
        let lesson=FlushDrawLesson.standard
        let next=lesson.counts(for:.nextCard),river=lesson.counts(for:.byRiver)
        assertEqual(next.hits,9);assertEqual(next.total,47)
        assertEqual(river.hits,378);assertEqual(river.total,1081)
        assertEqual(lesson.questions[0].correctPercent,100*9/47.0,accuracy:1e-10)
        assertEqual(lesson.questions[1].correctPercent,100*(1-(38.0/47)*(37.0/46)),accuracy:1e-10)
        assertEqual(river.total-river.hits,38*37/2)
        assertLessThan(lesson.questions[1].correctPercent,2*lesson.questions[0].correctPercent)
    }
    func testIndependentEvaluatorAllRunouts() {
        let lesson=FlushDrawLesson.standard
        let remaining=lesson.available
        var success=0,total=0
        for a in 0..<(remaining.count-1) {
            for b in (a+1)..<remaining.count {
                let seven=lesson.hero+lesson.flop+[remaining[a],remaining[b]]
                let rank=HandEvaluator.best(of:seven)
                if rank.category==5 || rank.category==8 { success+=1 }
                total+=1
            }
        }
        assertEqual(total,1081);assertEqual(success,378)
    }
    func testChoicesAndVersionedGrading() {
        let questions=FlushDrawLesson.standard.questions
        assertEqual(questions.count,2)
        assertEqual(Set(questions.map(\.id)).count,2)
        for q in questions {
            assertTrue(q.id.hasSuffix("-v1"))
            assertEqual(q.choices.filter { PracticeAttempt(question:q,answer:$0).isCorrect }.count,1)
            assertTrue(PracticeAttempt(question:q,answer:q.correctPercent).isCorrect)
            assertFalse(PracticeAttempt(question:q,answer:0).isCorrect)
            assertFalse(PracticeAttempt(question:q,answer:100).isCorrect)
            assertEqual(PracticeAttempt(question:q,answer:q.correctPercent).topic,.outs)
        }
        assertEqual(PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25).topic,.potOdds)
    }
    func testLegacyHistoryAndNewLessonCoexist() throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let history=PracticeHistory(fileURL:directory.appendingPathComponent("history.json"))
        let old=PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25)
        try history.save([old])
        let original=try Data(contentsOf:history.fileURL)
        // Old v1 schema has no new topic field: classification is derived from ID.
        let text=String(decoding:original,as:UTF8.self)
        assertFalse(text.contains("\"topic\""))
        let loaded=try history.load()
        assertEqual(loaded,[old]);assertEqual(loaded.first?.topic,.potOdds)
        let new=FlushDrawLesson.standard.questions.map { PracticeAttempt(question:$0,answer:$0.correctPercent) }
        try history.save(loaded+new)
        let reopened=try PracticeHistory(fileURL:history.fileURL).load()
        assertEqual(reopened,[old]+new)
        assertEqual(reopened.filter{$0.topic == .potOdds}.count,1)
        assertEqual(reopened.filter{$0.topic == .outs}.count,2)
        assertTrue(reopened.allSatisfy(\.isCorrect))
    }
}
