// Validation executable only. Not part of the iOS application target.
import Foundation
import SwiftUI
import PokerCore

@main
struct AppChecks {
    @MainActor static func main() async throws {
        let directory=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let file=directory.appendingPathComponent("history.json")
        if CommandLine.arguments.contains("--reload-regression") {
            let store=PracticeStore(fileURL:file)
            try store.record(PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25))
            let original=Data("corrupted-after-successful-load".utf8)
            try original.write(to:file)
            store.reload()
            guard store.errorMessage != nil else { print("FAIL reload did not surface corruption"); exit(1) }
            do { try store.record(PracticeAttempt(question:PotOddsQuestion.examples[0],answer:30)) } catch {}
            guard try Data(contentsOf:file)==original else {
                print("FAIL BUG-001: record after failed reload overwrote original corrupted history")
                exit(1)
            }
            try PracticeHistory(fileURL:file).saveArchive(PracticeArchive())
            store.reload()
            try store.record(PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25))
            precondition(store.attempts.count==1 && store.errorMessage==nil)
            print("PASS BUG-001: failed reload blocks writes; successful reload unlocks recording")
            return
        }
        // Catalog uses the same typed result and transaction as the original pot-odds lesson.
        let catalogFile = directory.appendingPathComponent("catalog/history.json")
        let catalogStore = PracticeStore(fileURL: catalogFile)
        guard let exercise = CourseCatalog.exercise(lesson: .potOdds, legacyKey: "pot-100-bet-50-v1"),
              let question = exercise.potOddsQuestion else { fatalError("Missing typed catalog route") }
        let catalogAttempt = PracticeAttempt(question: question, answer: 25)
        try catalogStore.record(catalogAttempt); try catalogStore.record(catalogAttempt)
        let restoredCatalog = PracticeStore(fileURL: catalogFile)
        precondition(restoredCatalog.attempts == [catalogAttempt])
        precondition(restoredCatalog.catalog.observations.count == 1)
        precondition(restoredCatalog.catalog.observations.first?.id == catalogAttempt.id)
        precondition(restoredCatalog.catalog.observations.first?.date == catalogAttempt.date)
        precondition(restoredCatalog.catalog.observations.first?.exerciseID == exercise.id)
        precondition(restoredCatalog.catalog.progress(for: .t11).covered == 1)
        let corruptCatalogBytes = Data("corrupt-catalog-history".utf8)
        try corruptCatalogBytes.write(to: catalogFile)
        restoredCatalog.reload()
        do { try restoredCatalog.record(catalogAttempt); fatalError("Catalog wrote after failed load") } catch {}
        let retainedCatalogBytes = try Data(contentsOf: catalogFile)
        precondition(retainedCatalogBytes == corruptCatalogBytes)
        precondition(restoredCatalog.catalog.observations.count == 1)
        let blockedCatalogParent = directory.appendingPathComponent("catalog-write-blocker")
        try Data("file".utf8).write(to: blockedCatalogParent)
        let retryCatalog = PracticeStore(fileURL: blockedCatalogParent.appendingPathComponent("history.json"))
        do { try retryCatalog.record(catalogAttempt); fatalError("Catalog expected write failure") } catch {}
        precondition(retryCatalog.catalog.observations.isEmpty && retryCatalog.attempts.isEmpty)
        try FileManager.default.removeItem(at: blockedCatalogParent)
        try retryCatalog.record(catalogAttempt); try retryCatalog.record(catalogAttempt)
        let retriedCatalog = PracticeStore(fileURL: blockedCatalogParent.appendingPathComponent("history.json"))
        precondition(retriedCatalog.attempts == [catalogAttempt] && retriedCatalog.catalog.observations.count == 1)
        print("PASS Catalog: typed exercise, UUID/date restoration, failed reload protection, no phantom on failed write and same-UUID retry")

        let first=PracticeStore(fileURL:file)
        precondition(first.attempts.isEmpty && first.errorMessage==nil)
        let attempt=PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25)
        try first.record(attempt);try first.record(attempt)
        precondition(first.attempts.count==1)
        let reloaded=PracticeStore(fileURL:file)
        precondition(reloaded.attempts==first.attempts)
        try Data("corrupted".utf8).write(to:file)
        let corrupt=PracticeStore(fileURL:file)
        precondition(corrupt.errorMessage != nil)
        do { try corrupt.record(attempt);fatalError("Corrupt data overwritten") } catch {}
        let preserved=try String(contentsOf:file,encoding:.utf8)
        precondition(preserved=="corrupted")
        try corrupt.clear()
        precondition(corrupt.attempts.isEmpty && corrupt.errorMessage==nil)
        print("PASS App persistence: record, duplicate ID, reload, corruption protection, explicit reset")

        let comparisonFile=directory.appendingPathComponent("comparisons.json")
        let comparisonStore=PracticeStore(fileURL:comparisonFile)
        let q=HandComparisonLesson.questions(seed:7)[0]
        let answer: HandComparisonAnswer = q.mode == .winner ? .winner(q.winner) : .bestFive(q.firstRank.bestFive)
        let comparison=HandComparisonAttempt(question:q,answer:answer)
        try comparisonStore.record(attempt)
        try comparisonStore.record(comparison);try comparisonStore.record(comparison)
        let recovered=PracticeStore(fileURL:comparisonFile)
        precondition(recovered.attempts==[attempt] && recovered.comparisons==[comparison])
        let invalidComparisonData=Data("corrupted-comparison-archive".utf8)
        try invalidComparisonData.write(to:comparisonFile)
        recovered.reload()
        do { try recovered.record(comparison);fatalError("Comparison write after failed reload") } catch {}
        let comparisonBytes=try Data(contentsOf:comparisonFile)
        precondition(comparisonBytes==invalidComparisonData)
        try recovered.clear()
        let cleared=PracticeStore(fileURL:comparisonFile)
        precondition(cleared.attempts.isEmpty && cleared.comparisons.isEmpty)
        print("PASS comparison progress: typed answers, mixed archive, same-ID retry, relaunch, failed reload protection and clear")

        let blockedParent=directory.appendingPathComponent("blocked-parent")
        try Data("ordinary-file".utf8).write(to:blockedParent)
        let blockedStore=PracticeStore(fileURL:blockedParent.appendingPathComponent("history.json"))
        do { try blockedStore.record(attempt);fatalError("Expected disk failure") } catch {}
        precondition(blockedStore.attempts.isEmpty && blockedStore.errorMessage != nil)
        let badComparisonStore=PracticeStore(fileURL:blockedParent.appendingPathComponent("comparison.json"))
        do { try badComparisonStore.record(comparison);fatalError("Expected comparison save failure") } catch {}
        precondition(badComparisonStore.comparisons.isEmpty && badComparisonStore.errorMessage != nil)
        try FileManager.default.removeItem(at:blockedParent)
        try blockedStore.record(attempt);try blockedStore.record(attempt)
        precondition(blockedStore.attempts==[attempt] && blockedStore.errorMessage==nil)
        try badComparisonStore.record(comparison);try badComparisonStore.record(comparison)
        precondition(badComparisonStore.comparisons==[comparison] && badComparisonStore.errorMessage==nil)
        print("PASS Save failure: no phantom result, error visible, same-ID retry succeeds once")

        let positionFile=directory.appendingPathComponent("positions.json")
        let positionStore=PracticeStore(fileURL:positionFile)
        let position=try PositionAttempt(question:PositionLesson.questions[0],answerIndex:0)
        try positionStore.record(position);try positionStore.record(position)
        try positionStore.record(attempt);try positionStore.record(comparison)
        let positionReload=PracticeStore(fileURL:positionFile)
        precondition(positionReload.positions==[position] && positionReload.attempts==[attempt] && positionReload.comparisons==[comparison])
        try Data("corrupt-positions".utf8).write(to:positionFile)
        positionReload.reload()
        do { try positionReload.record(position);fatalError("Position write after failed reload") } catch {}
        let positionBytes=try Data(contentsOf:positionFile)
        precondition(positionBytes==Data("corrupt-positions".utf8))
        try positionReload.clear()
        precondition(PracticeStore(fileURL:positionFile).positions.isEmpty)
        let positionBlocked=directory.appendingPathComponent("position-blocked")
        try Data("file".utf8).write(to:positionBlocked)
        let retryPosition=PracticeStore(fileURL:positionBlocked.appendingPathComponent("history.json"))
        do { try retryPosition.record(position);fatalError("Expected position save failure") } catch {}
        precondition(retryPosition.positions.isEmpty && retryPosition.errorMessage != nil)
        try FileManager.default.removeItem(at:positionBlocked)
        try retryPosition.record(position);try retryPosition.record(position)
        precondition(retryPosition.positions==[position])
        print("PASS positions: mixed archive, same-ID retry, restore, failed reload protection and clear")

        let evFile=directory.appendingPathComponent("ev.json")
        let evStore=PracticeStore(fileURL:evFile)
        let ev=try EVCallAttempt(question:EVCallQuestion.examples[0],decision:.call)
        try evStore.record(ev);try evStore.record(ev)
        try evStore.record(attempt);try evStore.record(comparison);try evStore.record(position)
        let evReload=PracticeStore(fileURL:evFile)
        precondition(evReload.evCalls==[ev] && evReload.attempts==[attempt] && evReload.comparisons==[comparison] && evReload.positions==[position])
        try Data("corrupt-ev".utf8).write(to:evFile);evReload.reload()
        do { try evReload.record(ev);fatalError("EV write after failed reload") } catch {}
        let evBytes=try Data(contentsOf:evFile)
        precondition(evBytes==Data("corrupt-ev".utf8))
        try evReload.clear()
        let evCleared=PracticeStore(fileURL:evFile)
        precondition(evCleared.evCalls.isEmpty && evCleared.positions.isEmpty && evCleared.comparisons.isEmpty && evCleared.attempts.isEmpty)
        let evBlocked=directory.appendingPathComponent("ev-blocked")
        try Data("file".utf8).write(to:evBlocked)
        let evRetry=PracticeStore(fileURL:evBlocked.appendingPathComponent("history.json"))
        do { try evRetry.record(ev);fatalError("Expected EV disk failure") } catch {}
        precondition(evRetry.evCalls.isEmpty && evRetry.errorMessage != nil)
        try FileManager.default.removeItem(at:evBlocked)
        try evRetry.record(ev);try evRetry.record(ev)
        precondition(evRetry.evCalls==[ev])
        print("PASS EV: mixed writes preserve all categories, same-ID retry, restore, failed reload, clear and save failure")

        let blockerFile=directory.appendingPathComponent("blockers.json")
        let blockerStore=PracticeStore(fileURL:blockerFile)
        let blocker=try BlockerAttempt(questionID:BlockerQuestion.examples[0].id,answerIndex:1)
        try blockerStore.record(blocker);try blockerStore.record(blocker)
        try blockerStore.record(attempt);try blockerStore.record(comparison);try blockerStore.record(position);try blockerStore.record(ev)
        let blockerReload=PracticeStore(fileURL:blockerFile)
        precondition(blockerReload.blockers==[blocker] && blockerReload.evCalls==[ev] && blockerReload.positions==[position] && blockerReload.comparisons==[comparison] && blockerReload.attempts==[attempt])
        try Data("corrupt-blockers".utf8).write(to:blockerFile);blockerReload.reload()
        do { try blockerReload.record(blocker);fatalError("Blocker write after failed reload") } catch {}
        let blockerBytes=try Data(contentsOf:blockerFile)
        precondition(blockerBytes==Data("corrupt-blockers".utf8))
        try blockerReload.clear()
        let blockerCleared=PracticeStore(fileURL:blockerFile)
        precondition(blockerCleared.blockers.isEmpty && blockerCleared.evCalls.isEmpty && blockerCleared.positions.isEmpty && blockerCleared.comparisons.isEmpty && blockerCleared.attempts.isEmpty)
        let blockerBlocked=directory.appendingPathComponent("blocker-blocked")
        try Data("file".utf8).write(to:blockerBlocked)
        let blockerRetry=PracticeStore(fileURL:blockerBlocked.appendingPathComponent("history.json"))
        do { try blockerRetry.record(blocker);fatalError("Expected blocker disk failure") } catch {}
        precondition(blockerRetry.blockers.isEmpty && blockerRetry.errorMessage != nil)
        try FileManager.default.removeItem(at:blockerBlocked)
        try blockerRetry.record(blocker);try blockerRetry.record(blocker)
        precondition(blockerRetry.blockers==[blocker])
        print("PASS blockers: five-category writes, same-ID retry, restore, failed reload, clear and disk failure")

        let courseFile=directory.appendingPathComponent("course.json")
        let courseStore=PracticeStore(fileURL:courseFile)
        for i in 0..<12 {
            let question=PotOddsQuestion.examples[i%3]
            try courseStore.record(PracticeAttempt(question:question,answer:i%3 == 1 ? 0 : question.correctPercent))
        }
        let courseBytes=try Data(contentsOf:courseFile)
        let courseReload=PracticeStore(fileURL:courseFile)
        let potProgress=courseReload.course.progress(.potOdds)
        precondition(potProgress.completed && potProgress.observations.count == 12 && potProgress.covered == 3 && potProgress.recentErrors == 4 && potProgress.repeatRecommended)
        precondition(courseReload.course.nextLesson == .combinations)
        let courseBytesAfter=try Data(contentsOf:courseFile)
        precondition(courseBytesAfter==courseBytes)
        print("PASS course: derived coverage and repeat after reload; 12 answers / 3 tasks / 4 errors; read preserves bytes")

        let model=GameViewModel()
        precondition(model.isPaused)
        let start=model.snapshot.revision
        try await Task.sleep(for:.milliseconds(650))
        precondition(model.snapshot.revision==start)
        model.setPaused(false)
        model.setPaused(true)
        try await Task.sleep(for:.milliseconds(650))
        precondition(model.snapshot.revision==start)
        model.setPaused(false)
        for _ in 0..<800 {
            if model.snapshot.complete { break }
            if model.snapshot.actor==0 {
                model.send(model.snapshot.legal.canCheck ? .check : .call)
            }
            try await Task.sleep(for:.milliseconds(100))
        }
        precondition(model.snapshot.complete,"GameViewModel did not finish")
        precondition(model.errorMessage==nil)
        precondition(model.snapshot.players.reduce(0){$0+$1.stack}==6000)
        print("PASS Application game loop: home paused, cancelled bot, resumed hand, hero actions, completed hand, 6000 chips conserved")
        print(model.snapshot.result)
        model.startFreshHand()
        precondition(model.snapshot.handNumber==2 && !model.snapshot.complete)
        model.setPaused(true)
        print("PASS Next hand; main-actor model integration finished")
        let afterGame=courseReload.course.progress(.potOdds)
        precondition(afterGame.observations.count == 12 && afterGame.latestCorrect == 2 && afterGame.recentErrors == 4 && afterGame.repeatRecommended)
        let afterGameBytes=try Data(contentsOf:courseFile)
        precondition(afterGameBytes == courseBytes)
        precondition(PracticeStore(fileURL:courseFile).course.progress(.potOdds).observations.count == 12)
        print("PASS course/game independence: completed hand and new hand preserve all 12 attempts, grades, recommendation and history bytes")
        try courseReload.clear()
        precondition(courseReload.course.observations.isEmpty && courseReload.course.repeatLessons.isEmpty)
        print("PASS course clear resets observations and recommendations")

    }
}
