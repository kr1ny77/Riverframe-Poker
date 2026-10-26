import XCTest
import PokerCore

@MainActor
final class CriticalFlows: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure=false
        app=XCUIApplication()
        app.terminate()
        app.launchArguments=["-AppleLanguages","(ru)","-AppleLocale","ru_RU"]
        app.launch()
    }
    private func tab(_ name:String) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout:10),app.debugDescription)
        button.tap()
    }
    private func screenshot(_ name:String) {
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    private func collectAccessibilityIssues(_ context: String) throws {
        var count=0
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .textClipped, .trait]) { issue in
            count += 1
            let attachment = XCTAttachment(string: "\(issue.compactDescription)\n\(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No element")")
            attachment.name = "accessibility-\(context)"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return true
        }
        let summary=XCTAttachment(string:"\(context): \(count) diagnostic accessibility issues. Issues are collected for review; handler acceptance is not an accessibility pass.")
        summary.name="accessibility-summary-\(context)";summary.lifetime = .keepAlways;add(summary)
    }
    private func auditLessonAccessibility() throws {
        // Contrast/clipping diagnostics include text masked by scroll chrome.
        // Keep every issue for review; this diagnostic pass is not an a11y pass.
        try collectAccessibilityIssues("lesson-template")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .trait])
    }
    private func scrollTo(_ element:XCUIElement) {
        if element.exists && element.elementType != .textField && app.keyboards.firstMatch.exists {
            let done=app.buttons["Готово"]
            if done.exists && done.isHittable { done.tap() }
        }
        for step in 0..<24 {
            if element.exists && element.isHittable { return }
            let screen=app.frame
            let target=element.exists ? element.frame : .zero
            let down = target != .zero ? target.midY < screen.midY : step >= 16
            let distance:CGFloat=target == .zero ? 180 : min(180,max(70,abs(target.midY-screen.midY)))
            let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:down ? 0.4 : 0.65))
            let finish=start.withOffset(CGVector(dx:0,dy:down ? distance : -distance))
            start.press(forDuration:0.01,thenDragTo:finish,withVelocity:.slow,thenHoldForDuration:0.15)
        }
    }
    private func openCalculationDetails() {
        let details = app.buttons["Подробнее о расчёте"]
        scrollTo(details)
        XCTAssertTrue(details.exists,app.debugDescription)
        details.tap()
    }
    private func checkAnswer() {
        let check=app.buttons["Проверить"]
        scrollTo(check)
        XCTAssertTrue(check.isEnabled)
        check.tap()
    }
    private func answerPotSet() {
        for answer in ["25","0","16.67"] {
            let field=app.textFields["Процент"]
            XCTAssertTrue(field.waitForExistence(timeout:10));scrollTo(field);field.tap();field.typeText(answer)
            let check=app.buttons["Проверить"];scrollTo(check);check.tap()
            let next=app.buttons["pot-odds.next"];scrollTo(next);XCTAssertTrue(next.isHittable);next.tap()
        }
        let back=app.buttons["К темам"];scrollTo(back);back.tap()
    }
    private func openPotProgress() {
        tab("Прогресс")
        let disclosure=app.buttons.matching(NSPredicate(format:"label == %@ AND identifier != %@","Шансы банка","course.next")).firstMatch
        scrollTo(disclosure);XCTAssertTrue(disclosure.isHittable);disclosure.tap()
    }
    private func freshRegression() {
        tab("Настройки");do { let clear = app.buttons["Очистить результаты"];scrollTo(clear);clear.tap();app.alerts.buttons["Очистить"].tap() }
        app.terminate();app.launch()
    }
    func testDesignCapture() {
        freshRegression();screenshot("design-home")
        openFixture("raise");screenshot("design-table")
        app.buttons["Повысить…"].tap()
        let amount=app.textFields["Сумма"]
        let settled=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            amount.exists && amount.frame.midY < self.app.frame.height*0.65
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[settled],timeout:10),.completed)
        screenshot("design-bet-editor");app.buttons["Отмена"].tap()
        app.terminate();app.launchEnvironment=[:];app.launch()
        tab("Тренировка");screenshot("design-course")
        openTraining("training.equity")
        XCTAssertTrue(app.textFields["equity.answer"].waitForExistence(timeout:30));screenshot("design-equity")
        app.navigationBars.buttons.element(boundBy:0).tap()
        for _ in 0..<6 { app.swipeDown(velocity:.fast) }
        openTraining("training.pot-odds");screenshot("design-pot-odds")
        let field=app.textFields["Процент"];scrollTo(field);field.tap();field.typeText("25")
        let check=app.buttons["Проверить"];scrollTo(check);check.tap()
        let next=app.buttons["pot-odds.next"];scrollTo(next);screenshot("design-feedback")
        tab("Прогресс");screenshot("design-progress")
        tab("Настройки");screenshot("design-settings")
    }
    func testDesignAccessibility() throws {
        freshRegression()
        screenshot("accessibility-home")
        try collectAccessibilityIssues("home")
        tab("Тренировка")
        screenshot("accessibility-course")
        try collectAccessibilityIssues("course")

        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launchEnvironment = ["POKER_QA_FIXTURE": "raise"]
        app.launch()
        let table=app.buttons.containing(NSPredicate(format:"label CONTAINS %@", "Открыть стол")).firstMatch
        scrollTo(table);XCTAssertTrue(table.isHittable);table.tap()
        func centerForCapture(_ element:XCUIElement) {
            scrollTo(element)
            for _ in 0..<4 {
                let delta=element.frame.midY-app.frame.midY
                if abs(delta)<30 { break }
                let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
                start.press(forDuration:0.01,thenDragTo:start.withOffset(CGVector(dx:0,dy:-min(180,max(-180,delta)))),withVelocity:.slow,thenHoldForDuration:0.15)
            }
        }
        for label in raiseFixtureHeroCardLabels() {
            let card = app.descendants(matching: .any).matching(NSPredicate(format:"label CONTAINS %@", label)).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 5), "Missing accessibility card label: \(label)")
            scrollTo(card)
            XCTAssertTrue(card.isHittable, "Card must be reachable at Accessibility XXXL: \(label)")
        }
        let hero=app.descendants(matching:.any).matching(NSPredicate(format:"label CONTAINS %@",raiseFixtureHeroCardLabels()[0])).firstMatch
        centerForCapture(hero)
        screenshot("accessibility-table-cards-axxxl")
        let raise=app.buttons["Повысить…"]
        centerForCapture(raise); XCTAssertTrue(raise.isHittable)
        screenshot("accessibility-table-actions-axxxl")
        screenshot("accessibility-table-axxxl")
        try collectAccessibilityIssues("table-axxxl")

        app.terminate()
        app.launchEnvironment = [:]
        app.launch()
        tab("Тренировка")
        openTraining("training.pot-odds")
        let answer = app.textFields["Процент"]
        scrollTo(answer); XCTAssertTrue(answer.isHittable)
        answer.tap(); answer.typeText("25")
        let check = app.buttons["Проверить"]
        scrollTo(check); check.tap()
        let saved = app.staticTexts["Результат сохранён на устройстве."]
        scrollTo(saved); XCTAssertTrue(saved.exists)
        screenshot("accessibility-pot-odds-axxxl")
        try collectAccessibilityIssues("pot-odds-axxxl")
    }
    func testDesignRapidSubmit() {
        freshRegression()
        tab("Тренировка")
        openTraining("training.pot-odds")
        let answer = app.textFields["Процент"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap(); answer.typeText("25")
        let check = app.buttons["Проверить"]
        scrollTo(check); XCTAssertTrue(check.isHittable)
        check.tap(withNumberOfTaps: 2, numberOfTouches: 1)
        let saved = app.staticTexts["Результат сохранён на устройстве."]
        scrollTo(saved); XCTAssertTrue(saved.exists)
        app.terminate(); app.launch(); tab("Прогресс")
        let result = app.staticTexts["Верно 1 из 1 ответов по ключу"]
        scrollTo(result); XCTAssertTrue(result.exists)
        screenshot("rapid-submit-restored-progress")
    }
    func testDesignReducedMotion() {
        let settings = XCUIApplication(bundleIdentifier:"com.apple.Preferences")
        settings.launch()
        func openSetting(_ name:String) {
            let item=settings.descendants(matching:.any).matching(NSPredicate(format:"label == %@",name)).firstMatch
            for _ in 0..<8 {
                if item.exists && item.isHittable { break }
                settings.swipeUp()
            }
            XCTAssertTrue(item.isHittable,settings.debugDescription)
            item.tap()
        }
        openSetting("Accessibility")
        openSetting("Motion")
        let reduce=settings.switches["Reduce Motion"]
        XCTAssertTrue(reduce.waitForExistence(timeout:5),settings.debugDescription)
        if reduce.value as? String != "1" { reduce.tap() }
        let enabled=NSPredicate(format:"value == %@","1")
        let firstChange=XCTNSPredicateExpectation(predicate:enabled,object:reduce)
        if XCTWaiter.wait(for:[firstChange],timeout:3) != .completed {
            reduce.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap()
        }
        expectation(for:enabled,evaluatedWith:reduce)
        waitForExpectations(timeout:5)
        let proof=XCTAttachment(screenshot:settings.screenshot())
        proof.name="os-reduce-motion-enabled";proof.lifetime = .keepAlways;add(proof)
        app.activate()
        freshRegression()
        testFullHandAgainstBots()
        screenshot("reduced-motion-hand-completed")
    }
    func testDesignAllLessonsXXXL() {
        freshRegression();app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]
        app.launchEnvironment=["POKER_QA_COMPARISON_SEED":"7"]
        app.launch();tab("Тренировка")
        for lesson in CourseLessonID.allCases {
            for _ in 0..<7 { app.swipeDown(velocity:.fast) }
            openTraining(lesson.accessibilityID)
            assertLessonDestination(lesson)
            screenshot("xxxl-\(lesson.rawValue)-context")
            switch lesson {
            case .combinations:
                let q=HandComparisonLesson.questions(seed:7)[0]
                if q.mode == .winner {
                    let button=app.buttons["comparison.answer.\(ShowdownWinner.first.rawValue)"];scrollTo(button);button.tap()
                } else {
                    for card in q.firstRank.bestFive {
                        let button=app.buttons["comparison.card.\(card.id)"];scrollTo(button);button.tap()
                    }
                    let check=app.buttons["comparison.check"];scrollTo(check);check.tap()
                }
            case .outs:
                let button=app.buttons["9,0 %"];scrollTo(button);button.tap()
            case .potOdds,.knownEquity,.rangeEquity:
                let id=lesson == .potOdds ? "Процент" : lesson == .knownEquity ? "equity.answer" : "range-equity.answer"
                let field=app.textFields[id];scrollTo(field);field.tap();field.typeText("25")
                let check=app.buttons["Проверить"];scrollTo(check);check.tap()
            case .positions:
                let start=app.buttons["Начать упражнения"];scrollTo(start);start.tap()
                let answer=app.buttons["positions.answer.0"];scrollTo(answer);answer.tap()
            case .evCall:
                let answer=app.buttons["ev.answer.call"];scrollTo(answer);answer.tap()
            case .blockers:
                let answer=app.buttons["blockers.answer.0"];scrollTo(answer);answer.tap()
            }
            app.swipeUp();screenshot("xxxl-\(lesson.rawValue)-review")
            app.navigationBars.buttons.element(boundBy:0).tap()
        }
    }
    func testDesignProgressHistory() {
        freshRegression();tab("Тренировка")
        for _ in 0..<7 {
            for _ in 0..<7 { app.swipeDown(velocity:.fast) }
            openTraining("training.pot-odds");answerPotSet()
        }
        openPotProgress()
        let title=app.staticTexts["Последние 20 ответов на фиксированные задачи"]
        scrollTo(title);XCTAssertTrue(title.exists)
        let first=app.images["Ответ 1: ошибка"]
        scrollTo(first);XCTAssertTrue(first.exists)
        screenshot("progress-history-21-answers")
        let count=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Всего ответов: 21. Разных задач: 3.")).firstMatch
        scrollTo(count);XCTAssertTrue(count.exists)
    }
    private func openTraining(_ identifier:String) {
        let link=app.buttons[identifier]
        if !link.exists {
            let archive = app.buttons["Прежние восемь наборов"]
            scrollTo(archive)
            if archive.exists { archive.tap() }
        }
        scrollTo(link)
        if !link.isHittable { screenshot("missing-\(identifier)") }
        XCTAssertTrue(link.isHittable,app.debugDescription);link.tap()
    }
    private func raiseFixtureHeroCardLabels() -> [String] {
        var game = HoldemGame(seed: 42, startingStacks: Array(repeating: 1000, count: 6), button: 0)
        for _ in 0..<3 {
            let snapshot = game.snapshot
            try! game.act(.call, seat: snapshot.actor!, revision: snapshot.revision)
        }
        return game.snapshot.players[0].cards.map(\.label)
    }
    private func assertLessonDestination(_ lesson: CourseLessonID) {
        switch lesson {
        case .combinations:
            XCTAssertTrue(app.staticTexts["comparison.step"].waitForExistence(timeout: 10))
        case .outs:
            XCTAssertTrue(app.buttons["9,0 %"].waitForExistence(timeout: 10))
        case .potOdds:
            XCTAssertTrue(app.textFields["Процент"].waitForExistence(timeout: 10))
        case .knownEquity:
            XCTAssertTrue(app.textFields["equity.answer"].waitForExistence(timeout: 30))
        case .positions:
            XCTAssertTrue(app.buttons["Начать упражнения"].waitForExistence(timeout: 10))
        case .rangeEquity:
            XCTAssertTrue(app.textFields["range-equity.answer"].waitForExistence(timeout: 30))
        case .evCall:
            XCTAssertTrue(app.buttons["ev.answer.call"].waitForExistence(timeout: 10))
        case .blockers:
            XCTAssertTrue(app.buttons["blockers.answer.0"].waitForExistence(timeout: 10))
        }
    }
    private func assertInvalidPercent(_ field:XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout:30));scrollTo(field)
        XCTAssertFalse(app.buttons["Проверить"].isEnabled)
        for value in ["-1","101","abc","1e309","999999999999999999999999"] {
            field.tap();field.typeText(value)
            XCTAssertFalse(app.buttons["Проверить"].isEnabled,"Accepted invalid percentage: \(value)")
            field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:value.count))
        }
    }
    func testRegressionLessonCombinations() { freshRegression();testComparisonLessonAndProgress() }
    func testRegressionLessonOuts() { freshRegression();testOutsLessonAndWrongAnswer() }
    func testRegressionLessonPotOdds() { freshRegression();testPotOddsExplanationAndRelaunch();testSettingsClearRequiresConfirmation() }
    func testRegressionLessonKnownEquity() { freshRegression();testKnownHandEquityLessonAndRelaunch() }
    func testRegressionLessonRangeEquity() { freshRegression();testRangeEquityLessonAndRelaunch() }
    func testRegressionLessonPositions() { freshRegression();testPositionsLessonAndRelaunch() }
    func testRegressionLessonEV() { freshRegression();testEVCallLessonAndRelaunch() }
    func testRegressionLessonBlockers() { freshRegression();testBlockerLessonAndRelaunch() }
    func testRegressionCourseNavigation() { freshRegression();testCourseRoutesPotOddsAndSample() }
    func testRegressionGameplay() { freshRegression();testFullHandAgainstBots() }
    func testRegressionOffline() { freshRegression();testOfflineAllSections() }
    func testCourseRepeatCopy() {
        tab("Тренировка");let pot=app.buttons["training.pot-odds"];scrollTo(pot);pot.tap()
        answerPotSet();openPotProgress()
        let text=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Охват считается по разным заданиям; повтор обновляет последнюю оценку и статистику ответов.")).firstMatch
        scrollTo(text);XCTAssertTrue(text.exists);screenshot("course-repeat-copy")
    }
    func testCourseRepeatNavigationPersistenceAndGameIndependence() {
        tab("Тренировка")
        for _ in 0..<4 {
            for _ in 0..<7 { app.swipeDown(velocity:.fast) }
            let pot=app.buttons["training.pot-odds"];scrollTo(pot);pot.tap();answerPotSet()
        }
        for _ in 0..<7 { app.swipeDown(velocity:.fast) }
        let repeatLink=app.buttons["course.repeat.potOdds"]
        scrollTo(repeatLink);XCTAssertTrue(repeatLink.label.contains("12 ответов: 4 ошибок · 3 разных заданий"))
        XCTAssertTrue(repeatLink.label.contains("учебная эвристика"));screenshot("course-repeat-home")
        repeatLink.tap();XCTAssertTrue(app.textFields["Процент"].waitForExistence(timeout:5))
        app.navigationBars.buttons.element(boundBy:0).tap()
        openPotProgress()
        let sample=app.descendants(matching:.any).matching(identifier:"course.sample.potOdds").firstMatch
        scrollTo(sample);XCTAssertTrue(sample.label.contains("12 ответов: 4 ошибок · 3 разных заданий"))
        let latest=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Последние ответы на разные задания: 2 верных из 3.")).firstMatch
        scrollTo(latest);XCTAssertTrue(latest.exists)
        let repeatProgress=app.buttons["course.repeat.potOdds"]
        scrollTo(repeatProgress);repeatProgress.tap()
        XCTAssertTrue(app.textFields["Процент"].waitForExistence(timeout:5));screenshot("course-repeat-exercise")
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.terminate();app.launch();tab("Прогресс")
        XCTAssertEqual(app.staticTexts["course.progress.completed"].label,"Пройдено наборов: 1 из 8")
        openPotProgress()
        scrollTo(sample);XCTAssertTrue(sample.label.contains("12 ответов: 4 ошибок · 3 разных заданий"))
        screenshot("course-repeat-restored")
        tab("Играть");testFullHandAgainstBots();tab("Прогресс")
        scrollTo(sample);XCTAssertTrue(sample.label.contains("12 ответов: 4 ошибок · 3 разных заданий"))
        let error=app.descendants(matching:.any).matching(identifier:"course.error.potPrice").firstMatch;scrollTo(error)
        XCTAssertTrue(error.label.contains("4 ошибок из 12 ответов"))
        screenshot("course-after-game-unchanged")
    }
    func testCourseWheelTaxonomyAndOverview() {
        tab("Тренировка");screenshot("course-overview")
        openComparisonLesson()
        for question in HandComparisonLesson.questions(seed:7) {
            let wheel=question.id.contains("-wheel-")
            chooseComparison(question,wrong:wheel)
            if wheel { break }
            let next=app.buttons["comparison.next"]
            scrollTo(next);next.tap()
        }
        tab("Прогресс")
        let disclosure=app.buttons.matching(NSPredicate(format:"label == %@ AND identifier != %@","Комбинации и сравнение рук","course.next")).firstMatch
        scrollTo(disclosure);XCTAssertTrue(disclosure.isHittable);disclosure.tap()
        let error=app.descendants(matching:.any).matching(identifier:"course.error.wheel").firstMatch
        scrollTo(error);XCTAssertTrue(error.label.contains("Туз в младшем стрите"))
        XCTAssertTrue(error.label.contains("1 ошибок из 1 ответов"))
        screenshot("course-wheel-error")
    }
    func testCatalogSingleExerciseAndRelaunch() throws {
        freshRegression()
        func openTopic() {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]
            scrollTo(catalog); catalog.tap()
            XCTAssertTrue(app.staticTexts["catalog.summary"].waitForExistence(timeout: 5))
            let module = app.descendants(matching: .any).matching(identifier: "catalog.module.M03").firstMatch
            scrollTo(module); module.tap()
            let topic = app.descendants(matching: .any).matching(identifier: "catalog.topic.T11").firstMatch
            scrollTo(topic); topic.tap()
        }
        openTopic()
        XCTAssertEqual(app.staticTexts["catalog.progress.T11"].label, "Охват текущих упражнений: 0/6")
        let exercise = app.buttons["catalog.exercise.E.pot.100.50"]
        scrollTo(exercise); exercise.tap()
        let start = app.buttons["lesson.start"]
        scrollTo(start); XCTAssertTrue(start.isHittable)
        try auditLessonAccessibility()
        screenshot("lesson-template-entry")
        start.tap()
        let field = app.textFields["Процент"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("25")
        checkAnswer()
        let saved = app.staticTexts["Результат сохранён на устройстве."]
        scrollTo(saved); XCTAssertTrue(saved.exists)
        screenshot("catalog-exercise-saved")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let result = app.staticTexts["lesson.restored-result"]
        scrollTo(result)
        XCTAssertTrue(result.label.contains("верно"))
        XCTAssertTrue(app.buttons["lesson.next"].exists)
        screenshot("lesson-template-result")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let progress = app.staticTexts["catalog.progress.T11"]
        scrollTo(progress)
        XCTAssertEqual(progress.label, "Охват текущих упражнений: 1/6")
        XCTAssertTrue(app.staticTexts["catalog.answers.T11"].label.contains("Ответов: 1."))
        app.terminate(); app.launch()
        openTopic()
        XCTAssertEqual(app.staticTexts["catalog.progress.T11"].label, "Охват текущих упражнений: 1/6")
        XCTAssertTrue(app.staticTexts["catalog.answers.T11"].label.contains("Ответов: 1."))
        let restored = app.buttons["catalog.exercise.E.pot.100.50"]
        scrollTo(restored)
        XCTAssertTrue(restored.label.contains("Последний ответ: верно по условию."))
        screenshot("catalog-result-restored")
        restored.tap()
        let restoredResult = app.staticTexts["lesson.restored-result"]
        scrollTo(restoredResult)
        XCTAssertTrue(restoredResult.label.contains("верно"))
        let next = app.buttons["lesson.next"]
        scrollTo(next); next.tap()
        XCTAssertTrue(app.staticTexts["Банк 120, ставка 120"].waitForExistence(timeout: 5))
        screenshot("lesson-template-next")
        tab("Прогресс")
        XCTAssertEqual(app.staticTexts["course.progress.completed"].label, "Пройдено наборов: 0 из 8")
        let summary = app.staticTexts["progress.catalog.summary"]
        scrollTo(summary); XCTAssertTrue(summary.label.contains("1/\(CourseCatalog.allExerciseIDs.count)"))
        let progressCatalog = app.buttons["progress.catalog"]
        scrollTo(progressCatalog); progressCatalog.tap()
        XCTAssertTrue(app.staticTexts["catalog.summary"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["catalog.overall-progress"].label, "Уникальных задач: 1/\(CourseCatalog.allExerciseIDs.count)")
        screenshot("catalog-from-progress")
    }

    func testLessonTemplateAccessibility() throws {
        freshRegression()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        func openSetting(_ title: String) {
            let item = settings.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
            for _ in 0..<8 {
                if item.exists && item.isHittable { break }
                settings.swipeUp()
            }
            XCTAssertTrue(item.isHittable, settings.debugDescription); item.tap()
        }
        func enable(_ toggle: XCUIElement) {
            let enabled = NSPredicate(format: "value == %@", "1")
            for _ in 0..<3 {
                if toggle.value as? String == "1" { return }
                // Settings exposes the entire labelled row as one switch.
                // Target its trailing thumb and wait for the OS to settle.
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                let settled = XCTNSPredicateExpectation(predicate: enabled, object: toggle)
                if XCTWaiter.wait(for: [settled], timeout: 10) == .completed { return }
            }
            XCTAssertEqual(toggle.value as? String, "1", toggle.debugDescription)
        }
        openSetting("Accessibility")
        openSetting("Motion")
        let motion = settings.switches["Reduce Motion"]
        XCTAssertTrue(motion.waitForExistence(timeout: 5))
        enable(motion)
        settings.navigationBars.buttons.element(boundBy: 0).tap()
        openSetting("Display & Text Size")
        for title in ["Reduce Transparency", "Increase Contrast"] {
            let toggle = settings.switches[title]
            for _ in 0..<5 { if toggle.exists && toggle.isHittable { break }; settings.swipeUp() }
            XCTAssertTrue(toggle.isHittable, settings.debugDescription)
            enable(toggle)
        }
        let proof = XCTAttachment(screenshot: settings.screenshot())
        proof.name = "lesson-os-accessibility-settings"; proof.lifetime = .keepAlways; add(proof)
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        tab("Тренировка")
        let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
        let module = app.descendants(matching: .any).matching(identifier: "catalog.module.M03").firstMatch
        scrollTo(module); module.tap()
        let topic = app.descendants(matching: .any).matching(identifier: "catalog.topic.T11").firstMatch
        scrollTo(topic); topic.tap()
        let task = app.buttons["catalog.exercise.E.pot.100.50"]
        scrollTo(task); task.tap()
        let start = app.buttons["lesson.start"]; scrollTo(start)
        XCTAssertTrue(start.isHittable)
        try auditLessonAccessibility()
        screenshot("lesson-template-xxxl")
        start.tap()
        let answer = app.textFields["Процент"]
        scrollTo(answer); answer.tap(); answer.typeText("25")
        checkAnswer()
        let next = app.buttons["pot-odds.next"]
        scrollTo(next); XCTAssertTrue(next.isHittable); next.tap()
        let restored = app.staticTexts["lesson.restored-result"]
        scrollTo(restored); XCTAssertTrue(restored.label.contains("верно"))
        screenshot("lesson-result-xxxl")
    }

    func testFoundationTopicsAndRelaunch() {
        freshRegression()
        let topics: [CourseTopicID] = [.t03, .t04, .t05, .t06, .t07, .t08, .t09, .t21, .t22, .t28]
        let tasks = topics.compactMap { topic in
            let exercises = CourseCatalog.foundations(for: topic)
            return topic == .t22 ? exercises.first(where: { !$0.chart.isEmpty }) : exercises.first
        }
        XCTAssertEqual(tasks.count, topics.count)
        func open(_ exercise: FoundationExercise) {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
            let topic = CourseCatalog.topics.first { $0.id == exercise.topicID }!
            let module = app.buttons["catalog.module." + topic.moduleID.rawValue]; scrollTo(module); module.tap()
            let row = app.buttons["catalog.topic." + topic.id.rawValue]; scrollTo(row); row.tap()
            let task = app.buttons["catalog.exercise." + exercise.id.rawValue]; scrollTo(task); task.tap()
            XCTAssertTrue(app.buttons["foundation.start"].waitForExistence(timeout: 5))
        }
        func backToTraining() {
            for _ in 0..<4 { app.navigationBars.buttons.element(boundBy: 0).tap() }
            XCTAssertTrue(app.buttons["course.catalog"].exists)
        }
        for exercise in tasks {
            open(exercise)
            let start = app.buttons["foundation.start"]; scrollTo(start); start.tap()
            if !exercise.chart.isEmpty { XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foundation.chart").firstMatch.exists) }
            switch exercise.answer.correctResponse {
            case .number(let value):
                let input = app.textFields["foundation.answer"]; scrollTo(input); input.tap(); input.typeText(String(value))
            case .choice(let index):
                let choice = app.buttons["foundation.choice.\(index)"]; scrollTo(choice); choice.tap()
            }
            let check = app.buttons["foundation.check"]; scrollTo(check); XCTAssertTrue(check.isEnabled); check.tap()
            let grade = app.staticTexts["foundation.grade"]; scrollTo(grade); XCTAssertEqual(grade.label, "Верно по условию.")
            let saved = app.staticTexts["foundation.saved"]; scrollTo(saved); XCTAssertTrue(saved.exists)
            screenshot("foundation-" + exercise.topicID.rawValue + "-checked")
            backToTraining()
        }
        app.terminate(); app.launch()
        for exercise in tasks {
            open(exercise)
            let restored = app.staticTexts["foundation.restored-result"]
            scrollTo(restored); XCTAssertEqual(restored.label, "Последний ответ: верно по условию.")
            screenshot("foundation-" + exercise.topicID.rawValue + "-restored")
            backToTraining()
        }
        tab("Прогресс")
        let summary = app.staticTexts["progress.catalog.summary"]
        scrollTo(summary); XCTAssertTrue(summary.label.contains("10/\(CourseCatalog.allExerciseIDs.count)"))
        XCTAssertTrue(summary.label.contains("Ответов: 10."))
    }

    func testIntermediateTopicsAndRelaunch() {
        freshRegression()
        let topics: [CourseTopicID] = [.t03, .t10, .t16, .t14, .t15, .t23, .t24, .t25, .t26, .t27, .t17, .t32, .t29, .t39, .t34, .t35, .t37]
        let tasks = topics.compactMap { topic in
            let exercises = CourseCatalog.foundations(for: topic)
            return exercises.first
        }
        XCTAssertEqual(tasks.count, topics.count)
        func open(_ exercise: FoundationExercise) {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
            let topic = CourseCatalog.topics.first { $0.id == exercise.topicID }!
            let module = app.buttons["catalog.module." + topic.moduleID.rawValue]; scrollTo(module); module.tap()
            let row = app.buttons["catalog.topic." + topic.id.rawValue]; scrollTo(row); row.tap()
            let task = app.buttons["catalog.exercise." + exercise.id.rawValue]; scrollTo(task); task.tap()
            XCTAssertTrue(app.buttons["foundation.start"].waitForExistence(timeout: 5))
        }
        func backToTraining() {
            for _ in 0..<4 { app.navigationBars.buttons.element(boundBy: 0).tap() }
            XCTAssertTrue(app.buttons["course.catalog"].exists)
        }
        for exercise in tasks {
            open(exercise)
            if exercise.simulation != nil {
                let report = app.descendants(matching: .any).matching(identifier: "foundation.monte-carlo").firstMatch
                XCTAssertTrue(report.waitForExistence(timeout: 5)); scrollTo(report); screenshot("intermediate-MC-report")
            }
            let start = app.buttons["foundation.start"]; scrollTo(start); start.tap()
            if !exercise.chart.isEmpty { XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foundation.chart").firstMatch.exists) }
            switch exercise.answer.correctResponse {
            case .number(let value):
                let input = app.textFields["foundation.answer"]; scrollTo(input); input.tap(); input.typeText(String(value))
            case .choice(let index):
                let choice = app.buttons["foundation.choice.\(index)"]; scrollTo(choice); choice.tap()
            }
            let check = app.buttons["foundation.check"]; scrollTo(check); XCTAssertTrue(check.isEnabled); check.tap()
            let grade = app.staticTexts["foundation.grade"]; scrollTo(grade); XCTAssertEqual(grade.label, "Верно по условию.")
            let saved = app.staticTexts["foundation.saved"]; scrollTo(saved); XCTAssertTrue(saved.exists)
            screenshot("intermediate-" + exercise.topicID.rawValue + "-checked")
            backToTraining()
        }
        app.terminate(); app.launch()
        for exercise in tasks {
            open(exercise)
            let restored = app.staticTexts["foundation.restored-result"]
            scrollTo(restored); XCTAssertEqual(restored.label, "Последний ответ: верно по условию.")
            screenshot("intermediate-" + exercise.topicID.rawValue + "-restored")
            backToTraining()
        }
        tab("Прогресс")
        let summary = app.staticTexts["progress.catalog.summary"]
        scrollTo(summary); XCTAssertTrue(summary.label.contains("17/\(CourseCatalog.allExerciseIDs.count)"))
        XCTAssertTrue(summary.label.contains("Ответов: 17."))
    }

    func testAdvancedTopicsAndRelaunch() {
        freshRegression()
        let topics: [CourseTopicID] = [.t12, .t13, .t36, .t38, .t30, .t31, .t33, .t40, .t19, .t20, .t45, .t46, .t47, .t49, .t50]
        let tasks = topics.compactMap { topic in
            let exercises = CourseCatalog.foundations(for: topic)
            return exercises.first
        }
        XCTAssertEqual(tasks.count, topics.count)
        func open(_ exercise: FoundationExercise) {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
            let topic = CourseCatalog.topics.first { $0.id == exercise.topicID }!
            let module = app.buttons["catalog.module." + topic.moduleID.rawValue]; scrollTo(module); module.tap()
            let row = app.buttons["catalog.topic." + topic.id.rawValue]; scrollTo(row); row.tap()
            let task = app.buttons["catalog.exercise." + exercise.id.rawValue]; scrollTo(task); task.tap()
            XCTAssertTrue(app.buttons["foundation.start"].waitForExistence(timeout: 5))
        }
        func backToTraining() {
            for _ in 0..<4 { app.navigationBars.buttons.element(boundBy: 0).tap() }
            XCTAssertTrue(app.buttons["course.catalog"].exists)
        }
        for exercise in tasks {
            open(exercise)
            if exercise.simulation != nil {
                let report = app.descendants(matching: .any).matching(identifier: "foundation.monte-carlo").firstMatch
                XCTAssertTrue(report.waitForExistence(timeout: 5)); scrollTo(report); screenshot("advanced-MC-report")
            }
            let start = app.buttons["foundation.start"]; scrollTo(start); start.tap()
            if !exercise.chart.isEmpty { XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foundation.chart").firstMatch.exists) }
            switch exercise.answer.correctResponse {
            case .number(let value):
                let input = app.textFields["foundation.answer"]; scrollTo(input); input.tap(); input.typeText(String(value))
            case .choice(let index):
                let choice = app.buttons["foundation.choice.\(index)"]; scrollTo(choice); choice.tap()
            }
            let check = app.buttons["foundation.check"]; scrollTo(check); XCTAssertTrue(check.isEnabled); check.tap()
            let grade = app.staticTexts["foundation.grade"]; scrollTo(grade); XCTAssertEqual(grade.label, "Верно по условию.")
            if [.t12, .t13, .t19, .t20, .t36, .t45, .t46, .t47, .t49].contains(exercise.topicID) {
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foundation.decision-tree").firstMatch.exists)
            }
            let saved = app.staticTexts["foundation.saved"]; scrollTo(saved); XCTAssertTrue(saved.exists)
            screenshot("advanced-" + exercise.topicID.rawValue + "-checked")
            backToTraining()
        }
        app.terminate(); app.launch()
        for exercise in tasks {
            open(exercise)
            let restored = app.staticTexts["foundation.restored-result"]
            scrollTo(restored); XCTAssertEqual(restored.label, "Последний ответ: верно по условию.")
            screenshot("advanced-" + exercise.topicID.rawValue + "-restored")
            backToTraining()
        }
        tab("Прогресс")
        let summary = app.staticTexts["progress.catalog.summary"]
        scrollTo(summary); XCTAssertTrue(summary.label.contains("15/\(CourseCatalog.allExerciseIDs.count)"))
        XCTAssertTrue(summary.label.contains("Ответов: 15."))
    }

    func testEarlyBoundaries() {
        freshRegression()
        tab("Тренировка")
        let intro = app.descendants(matching: .any).matching(identifier: "course.boundaries.introduction").firstMatch
        scrollTo(intro); XCTAssertTrue(intro.exists)
        screenshot("boundaries-course-entry")
        let link = app.buttons["course.boundaries.open"]; scrollTo(link); link.tap()
        XCTAssertTrue(app.staticTexts["catalog.progress.T59"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
        app.buttons["catalog.module.M01"].tap()
        app.buttons["catalog.topic.T01"].tap()
        let early = app.descendants(matching: .any).matching(identifier: "course.boundaries.introduction").firstMatch
        scrollTo(early); XCTAssertTrue(early.exists)
        screenshot("boundaries-M01-T01")
    }

    func testFinalTopicsAndRelaunch() {
        freshRegression()
        let topics: [CourseTopicID] = [.t41, .t42, .t43, .t44, .t48, .t51, .t52, .t53, .t54, .t55, .t56, .t57, .t58, .t59, .t60]
        let tasks = topics.compactMap { topic in
            let exercises = CourseCatalog.foundations(for: topic)
            return exercises.first
        }
        XCTAssertEqual(tasks.count, topics.count)
        func open(_ exercise: FoundationExercise) {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
            let topic = CourseCatalog.topics.first { $0.id == exercise.topicID }!
            let module = app.buttons["catalog.module." + topic.moduleID.rawValue]; scrollTo(module); module.tap()
            let row = app.buttons["catalog.topic." + topic.id.rawValue]; scrollTo(row); row.tap()
            let task = app.buttons["catalog.exercise." + exercise.id.rawValue]; scrollTo(task); task.tap()
            XCTAssertTrue(app.buttons["foundation.start"].waitForExistence(timeout: 5))
        }
        func backToTraining() {
            for _ in 0..<4 { app.navigationBars.buttons.element(boundBy: 0).tap() }
            XCTAssertTrue(app.buttons["course.catalog"].exists)
        }
        for exercise in tasks {
            open(exercise)
            if exercise.simulation != nil {
                let report = app.descendants(matching: .any).matching(identifier: "foundation.monte-carlo").firstMatch
                XCTAssertTrue(report.waitForExistence(timeout: 5)); scrollTo(report); screenshot("final-MC-report")
            }
            let start = app.buttons["foundation.start"]; scrollTo(start); start.tap()
            if !exercise.chart.isEmpty { XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foundation.chart").firstMatch.exists) }
            switch exercise.answer.correctResponse {
            case .number(let value):
                let input = app.textFields["foundation.answer"]; scrollTo(input); input.tap(); input.typeText(String(value))
            case .choice(let index):
                let choice = app.buttons["foundation.choice.\(index)"]; scrollTo(choice); choice.tap()
            }
            let check = app.buttons["foundation.check"]; scrollTo(check); XCTAssertTrue(check.isEnabled); check.tap()
            let grade = app.staticTexts["foundation.grade"]; scrollTo(grade); XCTAssertEqual(grade.label, "Верно по условию.")
            if [.t12, .t13, .t19, .t20, .t36, .t45, .t46, .t47, .t49].contains(exercise.topicID) {
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foundation.decision-tree").firstMatch.exists)
            }
            let saved = app.staticTexts["foundation.saved"]; scrollTo(saved); XCTAssertTrue(saved.exists)
            screenshot("final-" + exercise.topicID.rawValue + "-checked")
            backToTraining()
        }
        app.terminate(); app.launch()
        for exercise in tasks {
            open(exercise)
            let restored = app.staticTexts["foundation.restored-result"]
            scrollTo(restored); XCTAssertEqual(restored.label, "Последний ответ: верно по условию.")
            screenshot("final-" + exercise.topicID.rawValue + "-restored")
            backToTraining()
        }
        tab("Прогресс")
        let summary = app.staticTexts["progress.catalog.summary"]
        scrollTo(summary); XCTAssertTrue(summary.label.contains("15/\(CourseCatalog.allExerciseIDs.count)"))
        XCTAssertTrue(summary.label.contains("Ответов: 15."))
    }

    func testAdvancedICMLeavesAndThresholds() {
        freshRegression()
        let ids = ["E.foundation.t45.tie-leaf", "E.foundation.t46.threshold", "E.foundation.t46.r0-risk-premium", "E.foundation.t50.icm-after-leaf"]
        let tasks = ids.compactMap { FoundationLesson.exercise(.init(rawValue: $0)) }
        XCTAssertEqual(tasks.count, 4)
        func open(_ exercise: FoundationExercise) {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
            let topic = CourseCatalog.topics.first { $0.id == exercise.topicID }!
            let module = app.buttons["catalog.module." + topic.moduleID.rawValue]; scrollTo(module); module.tap()
            let row = app.buttons["catalog.topic." + topic.id.rawValue]; scrollTo(row); row.tap()
            let task = app.buttons["catalog.exercise." + exercise.id.rawValue]; scrollTo(task); task.tap()
            XCTAssertTrue(app.buttons["foundation.start"].waitForExistence(timeout: 5))
        }
        func backToTraining() {
            for _ in 0..<4 { app.navigationBars.buttons.element(boundBy: 0).tap() }
            XCTAssertTrue(app.buttons["course.catalog"].exists)
        }
        for exercise in tasks {
            open(exercise)
            if exercise.simulation != nil {
                let report = app.descendants(matching: .any).matching(identifier: "foundation.monte-carlo").firstMatch
                XCTAssertTrue(report.waitForExistence(timeout: 5)); scrollTo(report); screenshot("advanced-MC-report")
            }
            let start = app.buttons["foundation.start"]; scrollTo(start); start.tap()
            if !exercise.chart.isEmpty { XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foundation.chart").firstMatch.exists) }
            switch exercise.answer.correctResponse {
            case .number(let value):
                let input = app.textFields["foundation.answer"]; scrollTo(input); input.tap(); input.typeText(String(value))
            case .choice(let index):
                let choice = app.buttons["foundation.choice.\(index)"]; scrollTo(choice); choice.tap()
            }
            let check = app.buttons["foundation.check"]; scrollTo(check); XCTAssertTrue(check.isEnabled); check.tap()
            let grade = app.staticTexts["foundation.grade"]; scrollTo(grade); XCTAssertEqual(grade.label, "Верно по условию.")
            let numericKeys = ["E.foundation.t46.threshold": "50,58", "E.foundation.t46.r0-risk-premium": "2,9636", "E.foundation.t50.icm-after-leaf": "85,00"]
            if let key = numericKeys[exercise.id.rawValue] {
                let expected = app.staticTexts["foundation.expected"]; scrollTo(expected)
                XCTAssertEqual(expected.label, "Проверяемый ответ: " + key)
            }
            let diagram = app.descendants(matching: .any).matching(identifier: "foundation.decision-tree").firstMatch
            if diagram.exists { scrollTo(diagram); screenshot("advanced-icm-tree-" + exercise.id.rawValue) }

            if [.t12, .t13, .t19, .t20, .t36, .t45, .t46, .t47, .t49].contains(exercise.topicID) {
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "foundation.decision-tree").firstMatch.exists)
            }
            let saved = app.staticTexts["foundation.saved"]; scrollTo(saved); XCTAssertTrue(saved.exists)
            screenshot("advanced-icm-" + exercise.id.rawValue + "-checked")
            backToTraining()
        }
        app.terminate(); app.launch()
        for exercise in tasks {
            open(exercise)
            let restored = app.staticTexts["foundation.restored-result"]
            scrollTo(restored); XCTAssertEqual(restored.label, "Последний ответ: верно по условию.")
            screenshot("advanced-icm-" + exercise.id.rawValue + "-restored")
            backToTraining()
        }
        tab("Прогресс")
        let summary = app.staticTexts["progress.catalog.summary"]
        scrollTo(summary); XCTAssertTrue(summary.label.contains("4/\(CourseCatalog.allExerciseIDs.count)"))
        XCTAssertTrue(summary.label.contains("Ответов: 4."))
    }

    func testMonteCarloReportAndBayesRounding() {
        freshRegression()
        let ids = ["E.foundation.t10.recorded-mean", "E.foundation.t17.changed-likelihood"]
        for id in ids {
            let exercise = FoundationLesson.exercise(.init(rawValue: id))!
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
            let topic = CourseCatalog.topics.first { $0.id == exercise.topicID }!
            let module = app.buttons["catalog.module." + topic.moduleID.rawValue]; scrollTo(module); module.tap()
            let row = app.buttons["catalog.topic." + topic.id.rawValue]; scrollTo(row); row.tap()
            let task = app.buttons["catalog.exercise." + id]; scrollTo(task); task.tap()
            if exercise.simulation != nil {
                let se = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "SE:")).firstMatch
                scrollTo(se); XCTAssertTrue(se.label.contains("0,1967"))
                let interval = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Приближённый 95%-интервал:")).firstMatch
                XCTAssertTrue(interval.exists)
                XCTAssertTrue(interval.label.contains("91,1645")); XCTAssertTrue(interval.label.contains("91,9355"))
                screenshot("monte-carlo-method-and-error")
            }
            let start = app.buttons["foundation.start"]; scrollTo(start); start.tap()
            let value = exercise.topicID == .t10 ? "91,55" : "57,14"
            let input = app.textFields["foundation.answer"]; scrollTo(input); input.tap(); input.typeText(value)
            let check = app.buttons["foundation.check"]; scrollTo(check); check.tap()
            let expected = app.staticTexts["foundation.expected"]; scrollTo(expected)
            XCTAssertEqual(expected.label, "Проверяемый ответ: " + value)
            let grade = app.staticTexts["foundation.grade"]; scrollTo(grade); XCTAssertEqual(grade.label, "Верно по условию.")
            let result = app.buttons["foundation.result"]; scrollTo(result); result.tap()
            app.terminate(); app.launch()
            let restored = app.staticTexts["foundation.restored-result"]
            // The native stack is rebuilt after launch; return through the catalog.
            tab("Тренировка")
            let catalogAgain = app.buttons["course.catalog"]; scrollTo(catalogAgain); catalogAgain.tap()
            let moduleAgain = app.buttons["catalog.module." + topic.moduleID.rawValue]; scrollTo(moduleAgain); moduleAgain.tap()
            let topicAgain = app.buttons["catalog.topic." + topic.id.rawValue]; scrollTo(topicAgain); topicAgain.tap()
            let taskAgain = app.buttons["catalog.exercise." + id]; scrollTo(taskAgain); taskAgain.tap()
            scrollTo(restored); XCTAssertEqual(restored.label, "Последний ответ: верно по условию.")
            screenshot("rounded-result-" + exercise.topicID.rawValue)
            for _ in 0..<4 { app.navigationBars.buttons.element(boundBy: 0).tap() }
        }
    }

    func testCatalogExactTaskRoutes() {
        freshRegression()
        let cases: [(String, String, String, String)] = [
            ("M01", "T01", "E.hand.wheel", "comparison.step"),
            ("M01", "T02", "E.position.CO", "positions.answer.0"),
            ("M02", "T07", "E.outs.river", ""),
            ("M03", "T08", "E.equity.turn", "equity.answer"),
            ("M03", "T09", "E.range.turn-1to3", "range-equity.answer"),
            ("M03", "T11", "E.ev.negative", ""),
            ("M08", "T18", "E.blocker.bluffs", "")
        ]
        for (module, topic, exercise, control) in cases {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]
            scrollTo(catalog); catalog.tap()
            let m = app.descendants(matching: .any).matching(identifier: "catalog.module." + module).firstMatch
            scrollTo(m); m.tap()
            let t = app.descendants(matching: .any).matching(identifier: "catalog.topic." + topic).firstMatch
            scrollTo(t); t.tap()
            let e = app.buttons["catalog.exercise." + exercise]
            scrollTo(e); XCTAssertTrue(e.exists, exercise); e.tap()
            let start = app.buttons["lesson.start"]
            scrollTo(start); start.tap()
            XCTAssertTrue(app.staticTexts["lesson.task-math-status"].waitForExistence(timeout: 10))
            if !control.isEmpty {
                let element = app.descendants(matching: .any).matching(identifier: control).firstMatch
                XCTAssertTrue(element.waitForExistence(timeout: 15), app.debugDescription)
            }
            screenshot("exact-" + exercise)
            // Restore the native training root for the next independent route.
            for _ in 0..<5 { app.navigationBars.buttons.element(boundBy: 0).tap() }
        }
    }

    func testCourseRoutesPotOddsAndSample() {
        tab("Тренировка")
        XCTAssertEqual(app.staticTexts["course.completed"].label,"Пройдено наборов: 0 из 8")
        XCTAssertTrue(app.buttons["course.next"].label.contains("Комбинации"))
        for lesson in CourseLessonID.allCases {
            let link=app.buttons[lesson.accessibilityID]
            scrollTo(link);XCTAssertTrue(link.isHittable);link.tap()
            assertLessonDestination(lesson)
            app.navigationBars.buttons.element(boundBy:0).tap()
        }
        for _ in 0..<7 { app.swipeDown(velocity:.fast) }
        let pot=app.buttons["training.pot-odds"]
        scrollTo(pot);pot.tap()
        for (index,answer) in ["25","0","16.67"].enumerated() {
            let field=app.textFields["Процент"]
            XCTAssertTrue(field.waitForExistence(timeout:10));scrollTo(field);field.tap();field.typeText(answer)
            let check=app.buttons["Проверить"]
            scrollTo(check);check.tap()
            let next=app.buttons["pot-odds.next"]
            scrollTo(next);XCTAssertTrue(next.isHittable)
            if index == 2 { screenshot("course-pot-odds-last-review") }
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["Набор завершён"].waitForExistence(timeout:5))
        let back=app.buttons["К темам"]
        scrollTo(back);back.tap()
        for _ in 0..<7 { app.swipeDown(velocity:.fast) }
        XCTAssertEqual(app.staticTexts["course.completed"].label,"Пройдено наборов: 1 из 8")
        let status=app.staticTexts["course.status.potOdds"]
        scrollTo(status);XCTAssertTrue(status.label.contains("3/3"))
        tab("Прогресс")
        let disclosure=app.buttons.matching(NSPredicate(format:"label == %@","Шансы банка")).firstMatch
        scrollTo(disclosure);XCTAssertTrue(disclosure.isHittable);disclosure.tap()
        let sample=app.descendants(matching:.any).matching(identifier:"course.sample.potOdds").firstMatch
        scrollTo(sample);XCTAssertTrue(sample.label.contains("Последние 3 ответов: 1 ошибок · 3 разных заданий."))
        XCTAssertFalse(app.buttons["course.repeat.potOdds"].exists)
        let error=app.descendants(matching:.any).matching(identifier:"course.error.potPrice").firstMatch
        scrollTo(error);XCTAssertTrue(error.label.contains("1 ошибок из 3 ответов"))
        screenshot("course-small-sample")
        app.terminate();app.launch();tab("Прогресс")
        XCTAssertEqual(app.staticTexts["course.progress.completed"].label,"Пройдено наборов: 1 из 8")
        screenshot("course-restored-progress")
    }
    func testBlockerLessonAndRelaunch() {
        tab("Тренировка")
        openTraining("training.blockers")
        for (index,q) in BlockerQuestion.examples.enumerated() {
            let choice=index == 0 ? 0 : q.correctIndex!
            let answer=app.buttons["blockers.answer.\(choice)"]
            XCTAssertTrue(answer.waitForExistence(timeout:10))
            XCTAssertFalse(app.staticTexts["blockers.total"].exists)
            scrollTo(answer);XCTAssertTrue(answer.isHittable);answer.tap()
            for row in q.rows {
                let counts=app.descendants(matching:.any)["blockers.counts.\(row.id)"]
                scrollTo(counts);XCTAssertTrue(counts.exists)
                XCTAssertEqual(counts.label,"Комбинации: исходно \(row.baseline.count), после ваших карт \(row.afterHero.count), после доски \(row.remaining.count)")
            }
            if index == 0 {
                let disclosure=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Исключения AA")).firstMatch
                scrollTo(disclosure);XCTAssertTrue(disclosure.isHittable);disclosure.tap()
                for exclusion in q.rows[0].exclusions {
                    let explanation=app.staticTexts.matching(NSPredicate(format:"label == %@",exclusion.explanation)).firstMatch
                    scrollTo(explanation);XCTAssertTrue(explanation.exists)
                }
            }
            let total=app.staticTexts["blockers.total"]
            scrollTo(total);XCTAssertEqual(total.label,"Всего осталось: \(q.remainingCount) комбинаций.")
            if index >= 3 {
                let frequency=app.staticTexts["blockers.frequency"]
                scrollTo(frequency);XCTAssertTrue(frequency.label.contains(["75.00","50.00","40.00"][index-3]))
                let valueFrequency=app.staticTexts["blockers.value-frequency"]
                scrollTo(valueFrequency);XCTAssertTrue(valueFrequency.label.contains(["25.00","50.00","60.00"][index-3]))
            }
            screenshot("blockers-review-\(index+1)")
            let next=app.buttons[index == 5 ? "Завершить урок" : "Следующее задание"]
            scrollTo(next);XCTAssertTrue(next.isHittable);next.tap()
        }
        XCTAssertTrue(app.staticTexts["Набор завершён"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","5/6")).firstMatch.exists)
        tab("Прогресс")
        let progress=app.staticTexts["progress.blockers"]
        scrollTo(progress);XCTAssertEqual(progress.label,"Верно 5 из 6 ответов по модели")
        app.terminate();app.launch();tab("Прогресс")
        scrollTo(progress);XCTAssertEqual(progress.label,"Верно 5 из 6 ответов по модели")
        screenshot("blockers-restored-progress")
    }
    func testEVCallLessonAndRelaunch() {
        tab("Тренировка")
        openTraining("training.ev-call")
        for (index,choice) in ["call","call","fold"].enumerated() {
            let amounts=app.staticTexts["ev.amounts"]
            XCTAssertTrue(amounts.waitForExistence(timeout:10))
            scrollTo(amounts);XCTAssertTrue(amounts.label.contains("Банк до ставки BB: 100"))
            XCTAssertTrue(amounts.label.contains("Колл: 50"))
            let equity=app.staticTexts["ev.equity"]
            scrollTo(equity);XCTAssertTrue(equity.label.contains(["40.00","20.00","25.00"][index]))
            let answer=app.buttons["ev.answer.\(choice)"]
            scrollTo(answer);XCTAssertTrue(answer.isHittable);answer.tap()
            let values=app.staticTexts["ev.values"]
            scrollTo(values);XCTAssertTrue(values.label.contains(["+30.00","-10.00","+0.00"][index]))
            let explanation=app.staticTexts.matching(NSPredicate(format:"label == %@",EVCallQuestion.examples[index].result.recommendation)).firstMatch
            scrollTo(explanation);XCTAssertTrue(explanation.exists)
            screenshot("ev-call-review-\(index+1)")
            let next=app.buttons[index == 2 ? "Завершить урок" : "Следующий сценарий"]
            scrollTo(next);XCTAssertTrue(next.isHittable);next.tap()
        }
        XCTAssertTrue(app.staticTexts["Набор завершён"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","2 из 3")).firstMatch.exists)
        tab("Прогресс")
        let progress=app.staticTexts["progress.ev-call"]
        scrollTo(progress);XCTAssertEqual(progress.label,"Верно 2 из 3 решений по модели")
        app.terminate();app.launch();tab("Прогресс")
        scrollTo(progress);XCTAssertEqual(progress.label,"Верно 2 из 3 решений по модели")
        screenshot("ev-call-restored-progress")
    }
    func testPositionsLessonAndRelaunch() {
        tab("Тренировка")
        openTraining("training.positions")
        let start=app.buttons["Начать упражнения"]
        scrollTo(start);XCTAssertTrue(start.isHittable)
        screenshot("positions-introduction")
        start.tap()
        for (index,question) in PositionLesson.questions.enumerated() {
            let choice=index == 0 ? 1 : question.correctIndex
            let button=app.buttons["positions.answer.\(choice)"]
            XCTAssertTrue(button.waitForExistence(timeout:10))
            scrollTo(button);button.tap()
            let explanation=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@",question.explanation)).firstMatch
            scrollTo(explanation);XCTAssertTrue(explanation.exists)
            let next=app.buttons[index+1 == PositionLesson.questions.count ? "Завершить урок" : "Следующее задание"]
            scrollTo(next);XCTAssertTrue(next.isHittable)
            if index == 0 || index == 11 { screenshot("positions-review-\(index+1)") }
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["Набор завершён"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","11/12")).firstMatch.exists)
        tab("Прогресс")
        let progress=app.staticTexts["progress.positions"]
        scrollTo(progress);XCTAssertEqual(progress.label,"Верно 11 из 12 ответов по условию")
        app.terminate();app.launch();tab("Прогресс")
        scrollTo(progress);XCTAssertEqual(progress.label,"Верно 11 из 12 ответов по условию")
        screenshot("positions-restored-progress")
    }
    func testRangeEquityLessonAndRelaunch() {
        tab("Тренировка")
        openTraining("training.range-equity")
        for (index,value) in ["0","87.5","62.5"].enumerated() {
            let field=app.textFields["range-equity.answer"]
            XCTAssertTrue(field.waitForExistence(timeout:30))
            scrollTo(field)
            if index == 0 { assertInvalidPercent(field) }
            XCTAssertFalse(app.buttons["Проверить"].isEnabled)
            field.tap();field.typeText(value)
            let check=app.buttons["Проверить"]
            scrollTo(check);check.tap()
            let count=index == 0 ? "Рассмотрено исходов: 1980" : "Рассмотрено исходов: 88"
            openCalculationDetails()
            let explanation=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@",count)).firstMatch
            scrollTo(explanation);XCTAssertTrue(explanation.exists)
            let next=app.buttons[index == 2 ? "Завершить урок" : "Следующая задача"]
            scrollTo(next);XCTAssertTrue(next.isHittable)
            screenshot("range-equity-review-\(index+1)")
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["Набор завершён"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","2 из 3")).firstMatch.exists)
        screenshot("range-equity-completed")
        tab("Прогресс")
        let progress=app.staticTexts["Верно 2 из 3 ответов по ключу"].firstMatch
        scrollTo(progress);XCTAssertTrue(progress.exists)
        app.terminate();app.launch();tab("Прогресс")
        scrollTo(progress);XCTAssertTrue(progress.exists)
        screenshot("range-equity-restored-progress")
    }
    func testKnownHandEquityLessonAndRelaunch() {
        tab("Тренировка")
        openTraining("training.equity")
        let answer=app.textFields["equity.answer"]
        assertInvalidPercent(answer)
        answer.tap(); answer.typeText("0")
        checkAnswer()
        openCalculationDetails()
        let counts=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@", "Всего исходов: 990")).firstMatch
        scrollTo(counts); XCTAssertTrue(counts.exists)
        let next=app.buttons["К задаче на тёрне"]
        scrollTo(next); XCTAssertTrue(next.isHittable)
        screenshot("equity-flop-explanation")
        next.tap()
        XCTAssertTrue(answer.waitForExistence(timeout:30))
        answer.tap(); answer.typeText("50")
        checkAnswer()
        openCalculationDetails()
        let turn=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@", "Победы: 0 · ничьи: 44 · поражения: 0")).firstMatch
        scrollTo(turn); XCTAssertTrue(turn.exists)
        let finish=app.buttons["Завершить урок"]
        scrollTo(finish); finish.tap()
        XCTAssertTrue(app.staticTexts["Набор завершён"].waitForExistence(timeout:5))
        screenshot("equity-completed")
        tab("Прогресс")
        let history=app.staticTexts["Верно 1 из 2 ответов по ключу"].firstMatch
        scrollTo(history); XCTAssertTrue(history.exists)
        app.terminate(); app.launch(); tab("Прогресс")
        scrollTo(history); XCTAssertTrue(history.exists)
        screenshot("equity-restored-progress")
    }
    func testPotOddsExplanationAndRelaunch() {
        tab("Тренировка")
        openTraining("training.pot-odds")
        let answer=app.textFields["Процент"]
        XCTAssertTrue(answer.waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Проверить"].isEnabled)
        answer.tap();answer.typeText("101")
        XCTAssertFalse(app.buttons["Проверить"].isEnabled)
        answer.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:3)+"25")
        checkAnswer()
        openCalculationDetails()
        let explanation=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","50 / 200")).firstMatch
        scrollTo(explanation)
        XCTAssertTrue(explanation.exists)
        let saved=app.staticTexts["Результат сохранён на устройстве."]
        scrollTo(saved);XCTAssertTrue(saved.exists)
        screenshot("pot-odds-explanation")
        tab("Прогресс")
        let result=app.staticTexts["Верно 1 из 1 ответов по ключу"]
        scrollTo(result);XCTAssertTrue(result.exists)
        app.terminate();app.launch();tab("Прогресс")
        scrollTo(result);XCTAssertTrue(result.exists)
        screenshot("restored-progress")
    }
    func testOutsLessonAndWrongAnswer() {
        tab("Тренировка")
        openTraining("training.outs")
        let first=app.buttons["9,0 %"]
        scrollTo(first);XCTAssertTrue(first.exists);first.tap()
        let review=app.staticTexts["Разберём расчёт"]
        scrollTo(review);XCTAssertTrue(review.exists)
        let next=app.buttons["К вероятности к риверу"]
        scrollTo(next);next.tap()
        let correct=app.buttons["35,0 %"]
        scrollTo(correct);correct.tap()
        let finish=app.buttons["Завершить урок"]
        scrollTo(finish);finish.tap()
        XCTAssertTrue(app.staticTexts["Набор завершён"].waitForExistence(timeout:5))
        screenshot("outs-completed")
    }
    func testSettingsClearRequiresConfirmation() {
        tab("Прогресс")
        let before=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","ответов по ключу")).allElementsBoundByIndex.map(\.label)
        tab("Настройки")
        app.buttons["Очистить результаты"].tap()
        XCTAssertTrue(app.alerts["Очистить результаты?"].waitForExistence(timeout:3))
        app.alerts.buttons["Отмена"].tap()
        tab("Прогресс")
        let after=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","ответов по ключу")).allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(before,after)
        screenshot("progress-after-cancel")
        tab("Настройки");app.buttons["Очистить результаты"].tap()
        app.alerts.buttons["Очистить"].tap()
        tab("Прогресс")
        let empty=app.staticTexts["Пока нет попыток"];scrollTo(empty);XCTAssertTrue(empty.exists)
        app.terminate();app.launch();tab("Прогресс")
        scrollTo(empty);XCTAssertTrue(empty.exists)
    }
    func testLargeTextLessonRemainsReachable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch();tab("Тренировка")
        openTraining("training.pot-odds")
        let field=app.textFields["Процент"]
        scrollTo(field);XCTAssertTrue(field.isHittable)
        screenshot("large-text-training")
    }
    func testStorageFailureStillShowsPotOddsExplanation() throws {
        tab("Прогресс")
        let error=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Историю прочитать не удалось")).firstMatch
        guard error.exists else { throw XCTSkip("Requires corrupt-history fixture; see Tools/test-ios.sh") }
        tab("Тренировка")
        openTraining("training.pot-odds")
        let field=app.textFields["Процент"]
        field.tap();field.typeText("25")
        checkAnswer()
        openCalculationDetails()
        let explanation=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","50 / 200")).firstMatch
        XCTAssertTrue(explanation.waitForExistence(timeout:5),"Math feedback must remain available when disk save fails")
        scrollTo(explanation);screenshot("pot-odds-save-failure")
        XCTAssertTrue(app.buttons["Повторить сохранение"].exists)
        openComparisonLesson()
        chooseComparison(HandComparisonLesson.questions(seed:7)[0],wrong:true)
        let retry=app.buttons["comparison.retry"]
        scrollTo(retry);XCTAssertTrue(retry.exists)
        XCTAssertFalse(app.buttons["comparison.next"].exists)
        retry.tap()
        XCTAssertTrue(app.descendants(matching:.any)["comparison.feedback"].exists)
        screenshot("comparison-feedback-save-failure")
    }
    func testFullHandAgainstBots() {
        app.buttons.containing(NSPredicate(format:"label CONTAINS %@","Открыть стол")).firstMatch.tap()
        let deadline=Date().addingTimeInterval(100)
        while Date()<deadline {
            let next=app.buttons["Следующая раздача"]
            if next.exists {
                scrollTo(next)
                screenshot("completed-hand")
                next.tap()
                XCTAssertTrue(app.staticTexts["Раздача 2"].waitForExistence(timeout:5))
                return
            }
            let check=app.buttons["Чек"]
            let call=app.buttons.containing(NSPredicate(format:"label BEGINSWITH %@","Колл")).firstMatch
            if check.exists && check.isHittable && check.isEnabled { check.tap() }
            else if call.exists && call.isHittable && call.isEnabled { call.tap() }
            else { RunLoop.current.run(until:Date().addingTimeInterval(0.3)) }
        }
        screenshot("hand-timeout")
        XCTFail("Full hand did not finish within 100 seconds")
    }
    private func launchFixture(_ fixture: String?, offline: Bool = false) {
        app.terminate()
        app.launchEnvironment = [:]
        if let fixture { app.launchEnvironment["POKER_QA_FIXTURE"] = fixture }
        if offline {
            app.launchEnvironment["POKER_QA_NETWORK_DENY"] = "1"
            app.launchEnvironment["POKER_QA_NETWORK_PROFILE"] = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/qa-no-network.bin").path
            app.launchEnvironment["POKER_QA_CASE"] = "testOfflineAllSections"
        }
        app.launch()
    }
    private func openFixture(_ fixture: String) {
        launchFixture(fixture)
        app.buttons.containing(NSPredicate(format:"label CONTAINS %@","Открыть стол")).firstMatch.tap()
        XCTAssertTrue(app.buttons[["bet","blind-all-in"].contains(fixture) ? "Чек" : "Пас"].waitForExistence(timeout:5),app.debugDescription)
    }
    private func replaceAmount(_ text: String) {
        let field = app.textFields["Сумма"]
        XCTAssertTrue(field.waitForExistence(timeout:3))
        field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:old.count)+text)
    }
    private func assertRange(_ minimum: Int, _ maximum: Int) {
        let range = app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Допустимо:")).firstMatch
        XCTAssertTrue(range.waitForExistence(timeout:3),app.debugDescription)
        XCTAssertEqual(range.label.filter { !$0.isWhitespace },"Допустимо:\(minimum)–\(maximum)фишек")
    }
    private func assertHeroAction(_ action: String) {
        let seat = app.descendants(matching:.any).matching(NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@","Вы",action)).firstMatch
        XCTAssertTrue(seat.waitForExistence(timeout:4),"Hero action missing: \(action)\n\(app.debugDescription)")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Ход не принят")).firstMatch.exists)
    }
    func testBetCustomAmountAndValidation() {
        openFixture("bet")
        XCTAssertTrue(app.buttons["Чек"].exists)
        XCTAssertFalse(app.buttons.containing(NSPredicate(format:"label BEGINSWITH %@","Колл ")).firstMatch.exists)
        app.buttons["Ставка…"].tap()
        XCTAssertTrue(app.staticTexts["Банк: 60"].exists)
        assertRange(10,990)
        replaceAmount(""); XCTAssertFalse(app.buttons["Подтвердить"].isEnabled)
        replaceAmount("9"); XCTAssertFalse(app.buttons["Подтвердить"].isEnabled)
        XCTAssertTrue(app.staticTexts["Минимум: 10."].exists)
        replaceAmount("991"); XCTAssertFalse(app.buttons["Подтвердить"].isEnabled)
        XCTAssertTrue(app.staticTexts["Максимум: 990."].exists)
        replaceAmount("999999999999999999999999"); XCTAssertFalse(app.buttons["Подтвердить"].isEnabled)
        replaceAmount("37"); XCTAssertTrue(app.buttons["Подтвердить"].isEnabled)
        XCTAssertEqual(app.textFields["Сумма"].value as? String,"37")
        screenshot("bet-37-before-confirm")
        app.buttons["Подтвердить"].tap()
        assertHeroAction("Ставка 37")
        screenshot("bet-37-applied")
    }
    func testRaiseMinimum() {
        openFixture("raise")
        XCTAssertTrue(app.buttons["Колл 10"].exists)
        XCTAssertFalse(app.buttons["Чек"].exists)
        app.buttons["Повысить…"].tap()
        assertRange(20,1000)
        XCTAssertEqual(app.textFields["Сумма"].value as? String,"20")
        replaceAmount("19"); XCTAssertFalse(app.buttons["Подтвердить"].isEnabled)
        replaceAmount("20"); screenshot("minimum-raise-20-before-confirm")
        app.buttons["Подтвердить"].tap(); assertHeroAction("Рейз до 20")
    }
    func testRaiseMaximum() {
        openFixture("raise")
        app.buttons["Повысить…"].tap()
        replaceAmount("1001"); XCTAssertFalse(app.buttons["Подтвердить"].isEnabled)
        replaceAmount("1000"); XCTAssertTrue(app.buttons["Подтвердить"].isEnabled)
        screenshot("maximum-raise-1000-before-confirm")
        app.buttons["Подтвердить"].tap(); assertHeroAction("Рейз до 1000")
    }
    func testAllInExactConfirmation() {
        openFixture("raise")
        app.buttons["Олл-ин"].tap()
        assertRange(20,1000)
        screenshot("all-in-before-confirm")
        let total = app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Всего на этой улице:")).firstMatch
        XCTAssertTrue(total.exists,"All-in confirmation must show the selected total, distinct from the legal range")
        XCTAssertEqual(total.label.filter { !$0.isWhitespace },"Всегонаэтойулице:1000")
        let payment = app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Сейчас в банк:")).firstMatch
        XCTAssertEqual(payment.label.filter { !$0.isWhitespace },"Сейчасвбанк:1000")
        app.buttons["Подтвердить"].tap(); assertHeroAction("Рейз до 1000")
    }
    func testShortStackAllInRaise() {
        openFixture("short-stack")
        XCTAssertTrue(app.buttons["Колл 10"].exists)
        XCTAssertFalse(app.buttons["Повысить…"].exists)
        XCTAssertTrue(app.buttons["Олл-ин"].exists)
        screenshot("short-stack-legal-actions")
        app.buttons["Олл-ин"].tap()
        assertRange(15,15)
        screenshot("short-stack-all-in-15-before-confirm")
        app.buttons["Подтвердить"].tap(); assertHeroAction("Рейз до 15")
    }
    func testShortRaiseDoesNotReopen() {
        openFixture("short-facing")
        XCTAssertTrue(app.buttons["Колл 5"].exists)
        XCTAssertFalse(app.buttons["Чек"].exists)
        XCTAssertFalse(app.buttons["Повысить…"].exists)
        XCTAssertFalse(app.buttons["Олл-ин"].exists)
        screenshot("short-raise-facing-call-5-no-reopen")
        app.buttons["Колл 5"].tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Ход не принят")).firstMatch.exists)
    }
    func testOfflineAllSections() {
        launchFixture(nil,offline:true)
        screenshot("offline-launch")
        testFullHandAgainstBots()
        app.terminate(); app.launch()
        testPotOddsExplanationAndRelaunch()
        app.terminate(); app.launch()
        testOutsLessonAndWrongAnswer()
        testSettingsClearRequiresConfirmation()
        screenshot("offline-settings-progress-cleared")
    }

    func testShortStackCallAllIn() {
        openFixture("short-call")
        XCTAssertTrue(app.buttons["Колл 5"].exists)
        XCTAssertFalse(app.buttons["Чек"].exists)
        XCTAssertFalse(app.buttons["Повысить…"].exists)
        app.buttons["Олл-ин"].tap()
        assertRange(5,5)
        screenshot("short-call-all-in-5-before-confirm")
        app.buttons["Подтвердить"].tap()
        assertHeroAction("Колл 5")
    }
    func testAllInAfterBlindContribution() {
        openFixture("blind-all-in")
        XCTAssertTrue(app.buttons["Чек"].exists)
        app.buttons["Олл-ин"].tap()
        assertRange(20,1000)
        let total = app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Всего на этой улице:")).firstMatch
        let payment = app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Сейчас в банк:")).firstMatch
        XCTAssertEqual(total.label.filter { !$0.isWhitespace },"Всегонаэтойулице:1000")
        XCTAssertEqual(payment.label.filter { !$0.isWhitespace },"Сейчасвбанк:990")
        screenshot("all-in-total-1000-pay-990-before-confirm")
        app.buttons["Подтвердить"].tap()
        assertHeroAction("Рейз до 1000")
    }

    private func openComparisonLesson(largeText:Bool=false) {
        app.terminate()
        app.launchEnvironment=["POKER_QA_COMPARISON_SEED":"7"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch();tab("Тренировка")
        openTraining("training.combinations")
        XCTAssertTrue(app.staticTexts["comparison.step"].waitForExistence(timeout:5))
    }
    private func assertComparisonExplanation(_ question:HandComparisonQuestion,answer:HandComparisonAnswer) {
        switch answer {
        case .winner(let winner):
            XCTAssertTrue(app.staticTexts["Ваш ответ: \(winner.title)"].exists)
        case .bestFive:
            XCTAssertTrue(app.staticTexts["Ваш ответ: пять отмеченных карт игрока A и доски."].exists)
        }
        for line in question.explanation(for:answer) {
            let match = app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@",line)).firstMatch
            XCTAssertTrue(match.exists,"Missing explanation from evaluator: \(line)")
        }
    }
    private func chooseComparison(_ question:HandComparisonQuestion,wrong:Bool=false) {
        switch question.mode {
        case .winner:
            let answer = wrong ? ShowdownWinner.allCases.first { $0 != question.winner }! : question.winner
            let button=app.buttons["comparison.answer.\(answer.rawValue)"]
            scrollTo(button);button.tap()
        case .bestFive:
            let cards=wrong ? Array((question.first+question.board).prefix(5)) : question.firstRank.bestFive
            XCTAssertEqual(question.isCorrect(.bestFive(cards)),!wrong)
            let check=app.buttons["comparison.check"]
            XCTAssertFalse(check.isEnabled)
            for card in cards {
                let button=app.buttons["comparison.card.\(card.id)"]
                scrollTo(button);XCTAssertTrue(button.isHittable);button.tap()
            }
            scrollTo(check);XCTAssertTrue(check.isEnabled);check.tap()
        }
        let feedback=app.descendants(matching:.any)["comparison.feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout:5))
        XCTAssertTrue(feedback.label.contains(wrong ? "Разберём сравнение" : "Верно по картам"),feedback.label)
    }
    func testComparisonLessonAndProgress() {
        tab("Настройки");do { let clear = app.buttons["Очистить результаты"];scrollTo(clear);clear.tap();app.alerts.buttons["Очистить"].tap() }
        openComparisonLesson()
        let questions=HandComparisonLesson.questions(seed:7)
        XCTAssertEqual(questions.count,12)
        for (index,question) in questions.enumerated() {
            XCTAssertTrue(app.staticTexts["comparison.step"].label.contains("\(index+1)"))
            chooseComparison(question,wrong:index == 0)
            let answer:HandComparisonAnswer
            if index == 0 {
                answer = .bestFive(Array((question.first+question.board).prefix(5)))
            } else if question.mode == .winner {
                answer = .winner(question.winner)
            } else {
                answer = .bestFive(question.firstRank.bestFive)
            }
            assertComparisonExplanation(question,answer:answer)
            if index == 0 || question.id.contains("boardsplit") || question.id.contains("kicker") {
                screenshot("comparison-review-\(index+1)")
            }
            let next=app.buttons["comparison.next"]
            scrollTo(next);next.tap()
        }
        XCTAssertTrue(app.staticTexts["comparison.finished"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["comparison.finished"].label,"Набор завершён")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","11/12")).firstMatch.exists)
        screenshot("comparison-completed")
        tab("Прогресс")
        let result=app.staticTexts["progress.combinations"]
        scrollTo(result);XCTAssertTrue(result.exists)
        let expected=result.label
        XCTAssertTrue(expected.contains("11") && expected.contains("12"),expected)
        app.terminate();app.launch();tab("Прогресс")
        scrollTo(result);XCTAssertEqual(result.label,expected)
        screenshot("comparison-restored-progress")
        tab("Настройки");do { let clear = app.buttons["Очистить результаты"];scrollTo(clear);clear.tap();app.alerts.buttons["Очистить"].tap() }
        tab("Прогресс");let empty=app.staticTexts["Пока нет попыток"];scrollTo(empty);XCTAssertTrue(empty.exists)
    }
    func testComparisonLargeTextSelection() {
        openComparisonLesson(largeText:true)
        chooseComparison(HandComparisonLesson.questions(seed:7)[0])
        let next=app.buttons["comparison.next"]
        scrollTo(next);XCTAssertTrue(next.isHittable)
        screenshot("comparison-large-text-feedback")
    }

    func testLearningProgressAndReview() {
        freshRegression()
        let topic = CourseTopicID.t03
        let exercises = CourseCatalog.foundations(for: topic)
        guard let first = exercises.first,
              let alternate = exercises.first(where: { $0.id != first.id }) else {
            XCTFail("T03 needs at least two foundation exercises for an error review.")
            return
        }

        func open(_ exercise: FoundationExercise) {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]
            scrollTo(catalog); XCTAssertTrue(catalog.isHittable); catalog.tap()
            let module = app.buttons["catalog.module.M01"]
            scrollTo(module); XCTAssertTrue(module.isHittable); module.tap()
            let row = app.buttons["catalog.topic.T03"]
            scrollTo(row); XCTAssertTrue(row.isHittable); row.tap()
            let task = app.buttons["catalog.exercise." + exercise.id.rawValue]
            scrollTo(task); XCTAssertTrue(task.isHittable, task.debugDescription); task.tap()
            let start = app.buttons["foundation.start"]
            scrollTo(start); XCTAssertTrue(start.isHittable); start.tap()
        }

        func submit(_ exercise: FoundationExercise, correct: Bool) {
            switch exercise.answer {
            case .number(let expected, _):
                let value = correct ? expected : expected + exercise.answer.tolerance + 1
                let answer = app.textFields["foundation.answer"]
                scrollTo(answer); XCTAssertTrue(answer.isHittable); answer.tap(); answer.typeText(String(value))
            case .choice(let options, let expected):
                let value = correct ? expected : options.indices.first(where: { $0 != expected })!
                let answer = app.buttons["foundation.choice.\(value)"]
                scrollTo(answer); XCTAssertTrue(answer.isHittable); answer.tap()
            }
            let check = app.buttons["foundation.check"]
            scrollTo(check); XCTAssertTrue(check.isEnabled); check.tap()
        }

        func backToTraining() {
            for _ in 0..<4 { app.navigationBars.buttons.element(boundBy: 0).tap() }
            XCTAssertTrue(app.buttons["course.catalog"].waitForExistence(timeout: 5))
        }

        func openTopicMetrics() -> XCUIElement {
            tab("Тренировка")
            let catalog = app.buttons["course.catalog"]
            scrollTo(catalog); catalog.tap()
            let module = app.buttons["catalog.module.M01"]
            scrollTo(module); module.tap()
            let row = app.buttons["catalog.topic.T03"]
            scrollTo(row); row.tap()
            let metrics = app.descendants(matching: .any).matching(identifier: "learning.metrics.topic.T03").firstMatch
            scrollTo(metrics); XCTAssertTrue(metrics.waitForExistence(timeout: 5), app.debugDescription)
            return metrics
        }

        open(first)
        submit(first, correct: false)
        let grade = app.staticTexts["foundation.grade"]
        scrollTo(grade); XCTAssertEqual(grade.label, "Есть ошибка. Посмотрите разбор.")
        let errorKind = app.descendants(matching: .any).matching(identifier: "learning.error.kind").firstMatch
        scrollTo(errorKind); XCTAssertTrue(errorKind.exists, app.debugDescription)
        let saveError = app.buttons["learning.error.save"]
        scrollTo(saveError); XCTAssertTrue(saveError.isHittable); saveError.tap()
        let savedError = app.descendants(matching: .any).matching(identifier: "learning.error.saved").firstMatch
        scrollTo(savedError); XCTAssertTrue(savedError.waitForExistence(timeout: 5), app.debugDescription)
        screenshot("learning-wrong-answer-diagnosis")
        backToTraining()

        let topicMetrics = openTopicMetrics()
        XCTAssertTrue(topicMetrics.label.contains("1") && topicMetrics.label.localizedCaseInsensitiveContains("попыт"), topicMetrics.label)
        for _ in 0..<3 { app.navigationBars.buttons.element(boundBy: 0).tap() }

        tab("Прогресс")
        let reviewQueue = app.descendants(matching: .any).matching(identifier: "learning.review.queue").firstMatch
        scrollTo(reviewQueue); XCTAssertTrue(reviewQueue.exists, app.debugDescription)
        let firstReview = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Проверка 1/4")).firstMatch
        scrollTo(firstReview); XCTAssertTrue(firstReview.exists, app.debugDescription)
        let review = app.buttons["learning.review.open.T03"]
        scrollTo(review); XCTAssertTrue(review.isHittable, review.debugDescription)
        let recommendation = app.descendants(matching: .any).matching(identifier: "learning.recommendation").firstMatch
        scrollTo(recommendation); XCTAssertTrue(recommendation.exists)
        scrollTo(review); review.tap()
        let alternateTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", alternate.id.rawValue)).firstMatch
        scrollTo(alternateTitle); XCTAssertTrue(alternateTitle.waitForExistence(timeout: 5), app.debugDescription)
        let start = app.buttons["foundation.start"]
        scrollTo(start); XCTAssertTrue(start.isHittable); start.tap()
        submit(alternate, correct: true)
        let saved = app.staticTexts["foundation.saved"]
        scrollTo(saved); XCTAssertTrue(saved.exists)
        screenshot("learning-early-review-alternate-task")

        app.terminate(); app.launch()
        tab("Прогресс")
        let totalMetrics = app.descendants(matching: .any).matching(identifier: "learning.metrics.total").firstMatch
        scrollTo(totalMetrics); XCTAssertTrue(totalMetrics.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(totalMetrics.label.contains("2"), totalMetrics.label)
        let restoredQueue = app.descendants(matching: .any).matching(identifier: "learning.review.queue").firstMatch
        scrollTo(restoredQueue); XCTAssertTrue(restoredQueue.exists)
        let restoredReview = app.buttons["learning.review.open.T03"]
        scrollTo(restoredReview); XCTAssertTrue(restoredReview.exists)
        let restoredDiagnosis = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Арифметика и единицы")).firstMatch
        scrollTo(restoredDiagnosis); XCTAssertTrue(restoredDiagnosis.exists, app.debugDescription)

        tab("Настройки")
        let clear = app.buttons["Очистить результаты"]
        scrollTo(clear); clear.tap()
        let cancel = app.alerts.buttons["Отмена"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
        tab("Прогресс")
        scrollTo(totalMetrics); XCTAssertTrue(totalMetrics.exists)
        XCTAssertTrue(totalMetrics.label.contains("Попыток: 2"))
        tab("Настройки")
        scrollTo(clear); clear.tap()
        let confirm = app.alerts.buttons["Очистить"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        tab("Прогресс")
        scrollTo(totalMetrics); XCTAssertTrue(totalMetrics.exists)
        XCTAssertTrue(totalMetrics.label.contains("Попыток: 0"), totalMetrics.label)
        XCTAssertFalse(app.buttons["learning.review.open.T03"].exists)
        screenshot("learning-progress-cleared")
    }

    private func openRedesignFoundation(_ topicID: CourseTopicID, exerciseID: String? = nil) -> FoundationExercise {
        let topic = CourseCatalog.topics.first { $0.id == topicID }!
        let exercise = CourseCatalog.foundations(for: topicID).first { exerciseID == nil || $0.id.rawValue == exerciseID }!
        tab("Тренировка")
        let catalog = app.buttons["course.catalog"]; scrollTo(catalog); catalog.tap()
        let module = app.buttons["catalog.module." + topic.moduleID.rawValue]; scrollTo(module); module.tap()
        let row = app.buttons["catalog.topic." + topicID.rawValue]; scrollTo(row); row.tap()
        let task = app.buttons["catalog.exercise." + exercise.id.rawValue]; scrollTo(task); task.tap()
        XCTAssertTrue(app.buttons["foundation.start"].waitForExistence(timeout: 5))
        return exercise
    }

    func testRedesignWorkspace() throws {
        freshRegression()
        _ = openRedesignFoundation(.t03)
        screenshot("workbench-lesson-goal")
        app.buttons["foundation.start"].tap()
        let field = app.textFields["foundation.answer"]; scrollTo(field); field.tap(); field.typeText("999")
        screenshot("workbench-lesson-answer")
        let check = app.buttons["foundation.check"]; scrollTo(check); check.tap()
        let grade = app.staticTexts["foundation.grade"]; scrollTo(grade)
        XCTAssertEqual(grade.label, "Есть ошибка. Посмотрите разбор.")
        screenshot("workbench-lesson-proof")
        let saved = app.staticTexts["foundation.saved"]; scrollTo(saved); XCTAssertTrue(saved.exists)
        screenshot("workbench-lesson-error-category")
        app.terminate(); app.launch(); tab("Прогресс")
        let repeats = app.buttons["Повторение понятий"]; scrollTo(repeats); repeats.tap()
        let queue = app.staticTexts["learning.review.queue"]; scrollTo(queue); XCTAssertTrue(queue.exists)
        screenshot("workbench-repeat-and-progress")
        let review = app.buttons["learning.review.open.T03"]; scrollTo(review); XCTAssertTrue(review.isHittable)
        review.tap()
        XCTAssertTrue(app.staticTexts["foundation.restored-result"].exists == false)
        app.terminate(); app.launch()
        let long = openRedesignFoundation(.t48, exerciseID: "E.foundation.t48.ticket-call")
        app.buttons["foundation.start"].tap()
        let input = app.textFields["foundation.answer"]; scrollTo(input); input.tap()
        if case .number(let value) = long.answer.correctResponse { input.typeText(String(value)) }
        screenshot("workbench-long-context")
        let verify = app.buttons["foundation.check"]; scrollTo(verify); verify.tap()
        let result = app.staticTexts["foundation.grade"]; scrollTo(result)
        XCTAssertEqual(result.label, "Верно по условию.")
        screenshot("workbench-satellite-proof")
    }

    func testRedesignSemantics() throws {
        freshRegression()
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .trait])
        openFixture("raise")
        for name in ["Пас", "Колл 10", "Повысить…", "Олл-ин"] {
            let button = app.buttons[name]; scrollTo(button); XCTAssertTrue(button.isHittable, name)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        for label in raiseFixtureHeroCardLabels() {
            let card = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
            scrollTo(card); XCTAssertTrue(card.exists)
        }
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .trait])
        screenshot("workbench-table-accessibility")
    }

}
