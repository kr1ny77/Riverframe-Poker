import Foundation
import Testing
@testable import PokerCore

@Test func knownHandEquityExactCountsAndTies() throws {
    let share=KnownHandEquityResult(wins:2,ties:2,losses:4)
    #expect(share.equityPercent == 37.5)
    let royal=try KnownHandEquityQuestion(id:"royal",hero:[Card(id:12),Card(id:11)],opponent:[Card(id:25),Card(id:24)],board:[Card(id:8),Card(id:9),Card(id:10),Card(id:0)]).calculate()
    #expect(royal.wins == 44 && royal.ties == 0 && royal.losses == 0)
    #expect(royal.equityPercent == 100)
    let shared=try KnownHandEquityQuestion(id:"tie",hero:[Card(id:12),Card(id:24)],opponent:[Card(id:38),Card(id:50)],board:[Card(id:8),Card(id:22),Card(id:36),Card(id:39)])
    let tie=try shared.calculate()
    #expect(tie.total == 44 && tie.ties == 44 && tie.equityPercent == 50)
    // On the same rank-only board, neither player can make a flush.
    let flop=KnownHandEquityQuestion.examples[0]
    let result=try flop.calculate()
    #expect(result.total == 990)
    let reversed=try KnownHandEquityQuestion(id:"swap",hero:flop.opponent,opponent:flop.hero,board:flop.board).calculate()
    #expect(result.wins == reversed.losses && result.ties == reversed.ties)
    #expect(abs(result.equityPercent + reversed.equityPercent - 100) < 1e-10)
    // Each unordered runout occurs exactly twice in the independent ordered-turn decomposition.
    let known=Set(flop.hero + flop.opponent + flop.board)
    var wins=0, ties=0, losses=0
    for turn in (0..<52).map({Card(id:$0)}).filter({!known.contains($0)}) {
        let r=try KnownHandEquityQuestion(id:"turn",hero:flop.hero,opponent:flop.opponent,board:flop.board+[turn]).calculate()
        wins += r.wins; ties += r.ties; losses += r.losses
    }
    #expect(wins == 2*result.wins && ties == 2*result.ties && losses == 2*result.losses)
    print("EQUITY FLOP: wins=\(result.wins) ties=\(result.ties) losses=\(result.losses) total=\(result.total) equity=\(result.equityPercent)")
}

@Test func knownHandEquityRejectsImpossibleCardsAndPersists() throws {
    #expect(throws:(any Error).self) { try KnownHandEquityQuestion(id:"bad",hero:[Card(id:0),Card(id:1)],opponent:[Card(id:0),Card(id:2)],board:[Card(id:3),Card(id:4),Card(id:5)]) }
    #expect(throws:(any Error).self) { try KnownHandEquityQuestion(id:"bad",hero:[Card(id:0)],opponent:[Card(id:1),Card(id:2)],board:[]) }
    let question=KnownHandEquityQuestion.examples[1], result=try question.calculate()
    let correct=PracticeAttempt(question:question,result:result,answer:49.5)
    let wrong=PracticeAttempt(question:question,result:result,answer:49.49)
    #expect(correct.isCorrect && !wrong.isCorrect)
    #expect(correct.topic == .knownHandEquity)
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let history=PracticeHistory(fileURL:directory.appendingPathComponent("history.json"))
    let legacy=PracticeAttempt(question:PotOddsQuestion.examples[0],answer:25)
    try history.save([legacy,correct,wrong])
    #expect(try history.load() == [legacy,correct,wrong])
    #expect(try history.loadArchive().comparisons.isEmpty)
    #expect(result.explanation.contains { $0.contains("44") && $0.contains("ничьи") })
}
