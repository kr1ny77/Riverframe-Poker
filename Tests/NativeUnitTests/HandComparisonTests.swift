import Foundation
import Testing
@testable import PokerCore

@Test func handComparisonCoversEveryCategoryAndKnownShowdowns() {
    let questions = HandComparisonLesson.questions(seed: 0)
    #expect(questions.count == 12)
    #expect(Set(questions.flatMap { [$0.firstRank.category, $0.secondRank.category] }).isSuperset(of: Set(0...8)))
    #expect(questions.allSatisfy { $0.first.count == 2 && $0.second.count == 2 && $0.board.count == 5 })
    #expect(questions.allSatisfy { Set($0.first + $0.second + $0.board).count == 9 })

    let wheel = try! #require(questions.first { $0.id.contains("-wheel-") })
    #expect(wheel.firstRank.category == 4)
    #expect(wheel.firstRank.kickers == [5])
    #expect(wheel.explanation.joined(separator: " ").contains("Туз может быть младшей"))

    let set = try! #require(questions.first { $0.id.contains("-set-") })
    let setRank = try! #require([set.firstRank, set.secondRank].first { $0.category == 3 })
    #expect(setRank.kickers == [8, 13, 11])
    #expect(set.explanation.joined(separator: " ").contains("Карманная пара"))

    let kicker = try! #require(questions.first { $0.id.contains("-kicker-") })
    #expect(kicker.firstRank.category == 1 && kicker.secondRank.category == 1)
    #expect(Set([kicker.firstRank.kickers, kicker.secondRank.kickers]) == Set([[12, 14, 13, 7], [12, 14, 11, 7]]))

    let split = try! #require(questions.first { $0.id.contains("-boardsplit-") })
    #expect(split.winner == .split)
    #expect(split.firstRank.category == 8 && split.firstRank.kickers == [14])
    #expect(split.isCorrect(.winner(.split)))
}

@Test func generatedQuestionsStayValidAcrossSeeds() {
    for seed in 0..<100 {
        let questions = HandComparisonLesson.questions(seed: UInt64(seed))
        #expect(questions.count == 12)
        for question in questions {
            let physical = question.first + question.second + question.board
            #expect(Set(physical).count == 9)
            #expect(question.id.hasPrefix("hcmp-v1-"))
            #expect(question.isCorrect(.winner(question.winner)) == (question.mode == .winner))
            #expect(question.isCorrect(.bestFive(question.bestFive)) == (question.mode == .bestFive))
        }
    }
}

@Test func bestFiveQuestionsHaveOnePhysicalBestSubsetAndRejectWrongAnswers() {
    for question in HandComparisonLesson.questions(seed: 99) where question.mode == .bestFive {
        let available = question.first + question.board
        var matching = 0
        for a in 0..<3 { for b in (a + 1)..<4 { for c in (b + 1)..<5 { for d in (c + 1)..<6 { for e in (d + 1)..<7 {
            if HandEvaluator.best(of: [available[a], available[b], available[c], available[d], available[e]]) == question.firstRank { matching += 1 }
        } } } } }
        #expect(matching == 1)
        #expect(question.isCorrect(.bestFive(question.bestFive)))
        #expect(!question.isCorrect(.bestFive(Array(question.first + question.board).prefix(4).map { $0 })))
        #expect(!question.isCorrect(.bestFive([question.second[0]] + Array(question.bestFive.dropFirst()))))
        #expect(question.explanation(for: .bestFive(question.bestFive)).joined(separator: " ").contains("Выбрана сильнейшая комбинация"))
    }
}

@Test func comparisonQuestionDecodingRejectsTamperedCardsAndIDs() throws {
    let source = try #require(HandComparisonLesson.questions(seed: 7).first)
    let encoder = JSONEncoder()
    let data = try encoder.encode(source)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    var invalidID = object
    invalidID["id"] = "invalid-question"
    #expect(throws: (any Error).self) { try JSONDecoder().decode(HandComparisonQuestion.self, from: JSONSerialization.data(withJSONObject: invalidID)) }

    var duplicate = object
    duplicate["second"] = object["first"]
    #expect(throws: (any Error).self) { try JSONDecoder().decode(HandComparisonQuestion.self, from: JSONSerialization.data(withJSONObject: duplicate)) }

    var outsideDeck = object
    outsideDeck["board"] = [99, 1, 2, 3, 4]
    #expect(throws: (any Error).self) { try JSONDecoder().decode(HandComparisonQuestion.self, from: JSONSerialization.data(withJSONObject: outsideDeck)) }
}

@Test func comparisonAttemptsRoundTripAndDetectTamperedResult() throws {
    let question = try #require(HandComparisonLesson.questions(seed: 17).first { $0.mode == .winner })
    let answer = HandComparisonAnswer.winner(question.winner)
    let attempt = HandComparisonAttempt(question: question, answer: answer)
    #expect(attempt.isCorrect && attempt.isValid)
    let data = try JSONEncoder().encode(attempt)
    #expect(try JSONDecoder().decode(HandComparisonAttempt.self, from: data) == attempt)

    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["isCorrect"] = false
    let tampered = try JSONDecoder().decode(HandComparisonAttempt.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(!tampered.isValid)

    let bestFive = try #require(HandComparisonLesson.questions(seed: 17).first { $0.mode == .bestFive })
    let malformed = HandComparisonAttempt(question: bestFive, answer: .bestFive(Array(bestFive.bestFive.prefix(4))))
    #expect(!malformed.isCorrect)
    #expect(!malformed.isValid)
}

@Test func everyTemplateExplanationMatchesEvaluatorRanksAndWinner() throws {
    let questions = HandComparisonLesson.questions(seed: 0)
    let expectedCategories: [String: Set<Int>] = [
        "highcard": [0], "pair": [1], "twopair": [2], "set": [2, 3],
        "wheel": [0, 4], "flush": [5], "fullhouse": [6], "quads": [6, 7],
        "straightflush": [5, 8], "boardsplit": [8], "kicker": [1], "straight": [1, 4]
    ]
    let expectedKickers: [String: Set<[Int]>] = [
        "highcard": [[14, 13, 11, 9, 8], [13, 12, 11, 10, 8]],
        "pair": [[13, 11, 9, 7], [11, 14, 13, 9]],
        "twopair": [[13, 11, 9], [9, 7, 13]],
        "set": [[8, 13, 11], [13, 11, 8]],
        "wheel": [[5], [14, 9, 7, 6, 4]],
        "flush": [[14, 8, 5, 3, 2], [9, 8, 7, 5, 2]],
        "fullhouse": [[13, 9], [2, 13]],
        "quads": [[9, 14], [13, 9]],
        "straightflush": [[10], [12, 11, 9, 8, 7]],
        "boardsplit": [[14]],
        "kicker": [[12, 14, 13, 7], [12, 14, 11, 7]],
        "straight": [[10], [8, 14, 9, 7]]
    ]
    #expect(Set(questions.compactMap { $0.id.split(separator: "-").dropFirst(2).first.map(String.init) }) == Set(expectedCategories.keys))

    for question in questions {
        let key = String(question.id.split(separator: "-")[2])
        let ranks = [question.firstRank, question.secondRank]
        #expect(Set(ranks.map(\.category)) == expectedCategories[key])
        #expect(Set(ranks.map(\.kickers)) == expectedKickers[key])
        #expect(question.firstRank.bestFive.count == 5 && question.secondRank.bestFive.count == 5)

        let lines = question.explanation
        #expect(lines[0].hasPrefix("Игрок A: \(question.firstRank.title). \(rankExplanation(question.firstRank))"))
        #expect(lines[1].hasPrefix("Игрок B: \(question.secondRank.title). \(rankExplanation(question.secondRank))"))

        let independentWinner: ShowdownWinner
        if question.firstRank.category != question.secondRank.category {
            independentWinner = question.firstRank.category > question.secondRank.category ? .first : .second
        } else if question.firstRank.kickers == question.secondRank.kickers {
            independentWinner = .split
        } else {
            independentWinner = question.firstRank.kickers.lexicographicallyPrecedes(question.secondRank.kickers) ? .second : .first
        }
        #expect(question.winner == independentWinner)
        #expect(question.isCorrect(.winner(independentWinner)) == (question.mode == .winner))
        let wrongWinner: ShowdownWinner = independentWinner == .first ? .second : .first
        #expect(!question.isCorrect(.winner(wrongWinner)))

        if independentWinner == .split {
            #expect(lines.contains { $0.hasPrefix("Ничья: обе лучшие пятёрки имеют одинаковую категорию") })
            if key == "boardsplit" {
                #expect(lines.contains { $0.contains("Вся лучшая пятёрка лежит на доске") })
            }
        } else {
            #expect(lines.contains { $0.lowercased().contains("побеждает \(independentWinner.title.lowercased())") })
        }

        if question.mode == .bestFive {
            let best = question.firstRank.bestFive
            let answer = HandComparisonAnswer.bestFive(best)
            #expect(question.isCorrect(answer))
            let feedback = question.explanation(for: answer)
            #expect(feedback.contains { $0.hasPrefix("Выбрана сильнейшая комбинация: \(question.firstRank.title).") })
            let available = question.first + question.board
            let wrong = try #require((0..<available.count).flatMap { i in
                ((i + 1)..<available.count).flatMap { j in
                    ((j + 1)..<available.count).flatMap { k in
                        ((k + 1)..<available.count).flatMap { l in
                            ((l + 1)..<available.count).map { m in [available[i], available[j], available[k], available[l], available[m]] }
                        }
                    }
                }
            }.first { HandEvaluator.best(of: $0) < question.firstRank })
            let wrongRank = HandEvaluator.best(of: wrong)
            let wrongAnswer = HandComparisonAnswer.bestFive(wrong)
            #expect(!question.isCorrect(wrongAnswer))
            #expect(HandComparisonAttempt(question: question, answer: wrongAnswer).isValid)
            let wrongFeedback = question.explanation(for: wrongAnswer)
            #expect(wrongFeedback.contains("Выбранная пятёрка даёт \(wrongRank.title). \(rankExplanation(wrongRank))"))
            #expect(wrongFeedback.contains { $0.hasPrefix("Она слабее лучшей пятёрки игрока A:") })
        }
    }
}

private func rankExplanation(_ rank: HandRank) -> String {
    func label(_ value: Int) -> String { switch value { case 14: "A"; case 13: "K"; case 12: "Q"; case 11: "J"; default: String(value) } }
    let values = rank.kickers.map(label)
    return switch rank.category {
    case 0: "Сравниваются все пять старших карт: \(values.joined(separator: ", "))."
    case 1: "Пара \(values[0]); затем кикеры: \(values.dropFirst().joined(separator: ", "))."
    case 2: "Две пары: \(values[0]) и \(values[1]); затем кикер \(values[2])."
    case 3: "Тройка \(values[0]); затем кикеры: \(values.dropFirst().joined(separator: ", "))."
    case 4: "Старшая карта стрита — \(values[0]). Туз может быть младшей картой в стрите 5–4–3–2–A."
    case 5: "Во флеше сравниваются все пять рангов: \(values.joined(separator: ", "))."
    case 6: "Фулл-хаус: тройка \(values[0]) и пара \(values[1])."
    case 7: "Каре \(values[0]); затем кикер \(values[1])."
    default: "Стрит-флеш; старшая карта — \(values[0])."
    }
}
