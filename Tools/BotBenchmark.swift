// Standalone Release benchmark. Build/run with Tools/benchmark-bots.sh.
import Foundation
import PokerCore

@main struct BotBenchmark {
    static func main() throws {
        var corpus: [BotObservation] = []
        for seed: UInt64 in [42, 71, 113] {
            var game = HoldemGame(seed: seed, botSeed: 937)
            while !game.snapshot.complete {
                let state = game.snapshot
                if state.actor != 0, let observation = game.botObservation() { corpus.append(observation) }
                let legal = game.botObservation()!.legal
                try game.act(legal.canCheck ? .check : .call, seat: state.actor!, revision: state.revision)
            }
        }
        let count = Int(CommandLine.arguments.dropFirst().first ?? "1000") ?? 1000
        precondition(count >= 1000, "At least 1000 measurements per profile")
        let clock = ContinuousClock()
        var profiles: [[String: Any]] = []
        var checksum = 0
        for level in BotLevel.allCases {
            for index in 0..<50 {
                _ = try BotPolicy.decide(corpus[index % corpus.count], level: level, seed: UInt64(index))
            }
            var durations: [Double] = []
            for index in 0..<count {
                let start = clock.now
                let action = try BotPolicy.decide(corpus[index % corpus.count], level: level, seed: UInt64(index))
                let elapsed = start.duration(to: clock.now).components
                durations.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
                switch action { case .raiseTo(let chips): checksum &+= Int(chips); case .call: checksum &+= 1; default: break }
            }
            let sorted = durations.sorted()
            let p95 = sorted[Int(ceil(Double(count) * 0.95)) - 1]
            profiles.append(["level": level.rawValue, "samples": count, "p50_ms": sorted[count / 2],
                             "p95_ms": p95, "max_ms": sorted.last!, "pass": p95 <= 250, "raw_ms": durations])
        }
        let report: [String: Any] = ["policy_version": BotPolicy.version, "corpus_version": 1, "warmup_per_profile": 50, "budget_ms": 250,
            "environment": ProcessInfo.processInfo.operatingSystemVersionString, "checksum": checksum,
            "scope": "synchronous policy evaluation; excludes scheduling/UI/delay", "profiles": profiles]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        FileHandle.standardOutput.write(data)
        if profiles.contains(where: { ($0["pass"] as? Bool) != true }) { exit(1) }
    }
}
