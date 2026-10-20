import Foundation
import Combine
import SwiftUI
import PokerCore
#if DEBUG && targetEnvironment(simulator)
import Darwin
#endif

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var snapshot: GameSnapshot
    @Published private(set) var isPaused = true
    @Published private(set) var isBotThinking = false
    @Published var errorMessage: String?

    @Published private(set) var selectedBotLevel: BotLevel
    @Published private(set) var activeBotLevel: BotLevel
    private let defaults: UserDefaults
    private let decision: @Sendable (BotObservation, BotLevel, UInt64) throws -> PokerAction
    private let botDelay: Duration
    private var requestID = UUID()
    private var worker: Task<PokerAction, Error>?
    private var game: HoldemGame
    private var botTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, game suppliedGame: HoldemGame? = nil,
         botDelay: Duration = .milliseconds(550),
         decision: @escaping @Sendable (BotObservation, BotLevel, UInt64) throws -> PokerAction = {
             try BotPolicy.decide($0, level: $1, seed: $2)
         }) {
        self.defaults = defaults
        self.botDelay = botDelay
        self.decision = decision
        let level = defaults.string(forKey: "table.botLevel").flatMap(BotLevel.init(rawValue:)) ?? .amateur
        selectedBotLevel = level
        activeBotLevel = level
        #if DEBUG && targetEnvironment(simulator)
        SimulatorQA.isolateNetworkIfRequested()
        let newGame = SimulatorQA.makeGame() ?? HoldemGame()
        #else
        let newGame = HoldemGame()
        #endif
        game = suppliedGame ?? newGame
        snapshot = (suppliedGame ?? newGame).snapshot
    }

    deinit { botTask?.cancel(); worker?.cancel() }

    func selectBotLevel(_ level: BotLevel) {
        selectedBotLevel = level
        defaults.set(level.rawValue, forKey: "table.botLevel")
    }

    private func cancelBot() {
        requestID = UUID()
        botTask?.cancel()
        worker?.cancel()
        botTask = nil
        worker = nil
        isBotThinking = false
    }

    func startFreshHand() {
        cancelBot()
        do {
            try game.nextHand()
            activeBotLevel = selectedBotLevel
            snapshot = game.snapshot
            errorMessage = nil
            scheduleBotIfNeeded()
        } catch {
            errorMessage = "Не удалось начать следующую раздачу: \(error.localizedDescription)"
            scheduleBotIfNeeded()
        }
    }

    func send(_ action: PokerAction) {
        guard let actor = snapshot.actor, actor == 0, !isPaused else { return }
        cancelBot()
        do {
            try game.act(action, seat: 0, revision: snapshot.revision)
            snapshot = game.snapshot
            errorMessage = nil
            scheduleBotIfNeeded()
        } catch {
            errorMessage = "Ход не принят: \(error.localizedDescription)"
            snapshot = game.snapshot
            scheduleBotIfNeeded()
        }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            cancelBot()
        } else {
            scheduleBotIfNeeded()
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase != .active { setPaused(true) }
    }

    private func scheduleBotIfNeeded() {
        cancelBot()
        guard !isPaused, !snapshot.complete, let seat = snapshot.actor, seat != 0,
              let observation = game.botObservation() else { return }
        let expectedRevision = snapshot.revision
        let expectedHand = snapshot.handNumber
        let token = requestID
        let level = activeBotLevel
        let seed = game.botDecisionSeed
        let compute = decision
        let delay = botDelay
        isBotThinking = true
        botTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
                try Task.checkCancellation()
                let task = Task.detached(priority: .userInitiated) {
                    try Task.checkCancellation()
                    return try compute(observation, level, seed)
                }
                self?.worker = task
                let action = try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
                try Task.checkCancellation()
                guard let self, self.requestID == token, !self.isPaused,
                      !self.snapshot.complete, self.snapshot.handNumber == expectedHand,
                      self.snapshot.actor == seat, self.snapshot.revision == expectedRevision else { return }
                try self.game.act(action, seat: seat, revision: expectedRevision)
                self.snapshot = self.game.snapshot
                self.errorMessage = nil
                self.scheduleBotIfNeeded()
            } catch is CancellationError {
                // The owner invalidates the request before cancelling it.
            } catch {
                guard let self, self.requestID == token else { return }
                self.snapshot = self.game.snapshot
                self.errorMessage = "Бот не смог завершить ход: \(error.localizedDescription)"
                self.cancelBot()
            }
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
/// Test-only launch fixtures. Every state is reached with the public rules engine.
private enum SimulatorQA {
    static func isolateNetworkIfRequested() {
        guard ProcessInfo.processInfo.environment["POKER_QA_NETWORK_DENY"] == "1" else { return }
        // Debug Simulator-only QA: apply bytecode compiled for this host kernel.
        // It permits default operations and denies inbound/outbound IP networking.
        let profile = "qa-deny-ip"
        typealias SandboxApply = @convention(c) (UnsafePointer<CChar>, Int32, UnsafeMutableRawPointer) -> Int32
        let library = dlopen("/usr/lib/system/libsystem_sandbox.dylib",RTLD_NOW)
        let symbol = library.flatMap { dlsym($0,"__sandbox_ms") }
        let file = ProcessInfo.processInfo.environment["POKER_QA_NETWORK_PROFILE"] ?? ""
        let data = try? Data(contentsOf:URL(fileURLWithPath:file))
        let result: Int32
        if let symbol, let data, !data.isEmpty {
            let apply = unsafeBitCast(symbol,to:SandboxApply.self)
            result = data.withUnsafeBytes { bytes in
                var arguments = [UInt64(UInt(bitPattern:bytes.baseAddress!)),UInt64(bytes.count),0,0]
                return arguments.withUnsafeMutableBytes { buffer in
                    "Sandbox".withCString { apply($0,0,buffer.baseAddress!) }
                }
            }
        } else {
            result = -2
        }
        func probe(_ ip: String) -> Int32 {
            let descriptor = socket(AF_INET,SOCK_STREAM,0)
            guard descriptor >= 0 else { return errno }
            defer { close(descriptor) }
            _ = fcntl(descriptor,F_SETFL,O_NONBLOCK)
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = UInt16(443).bigEndian
            _ = ip.withCString { inet_pton(AF_INET,$0,&address.sin_addr) }
            let code = withUnsafePointer(to:&address) { pointer in
                pointer.withMemoryRebound(to:sockaddr.self,capacity:1) { connect(descriptor,$0,socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            return code == 0 ? 0 : errno
        }
        let external = result == 0 ? probe("1.1.1.1") : -1
        let loopback = result == 0 ? probe("127.0.0.1") : -1
        let proof: [String:Any] = ["sandbox_result":result,"profile":profile,"external_connect_errno":external,
            "loopback_connect_errno":loopback,"case":ProcessInfo.processInfo.environment["POKER_QA_CASE"] ?? "unknown",
            "profile_bytes":data?.count ?? 0, "process":ProcessInfo.processInfo.processIdentifier]
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("qa-network-\(UUID().uuidString).json")
        if let data = try? JSONSerialization.data(withJSONObject:proof,options:[.prettyPrinted,.sortedKeys]) { try? data.write(to:path) }
    }

    static func makeGame() -> HoldemGame? {
        guard let fixture = ProcessInfo.processInfo.environment["POKER_QA_FIXTURE"] else { return nil }
        let stacks: [Int64] = fixture == "short-call" ? [5,1000,1000,1000,1000,1000]
            : fixture == "short-stack" ? [15,1000,1000,1000,1000,1000]
            : fixture == "short-facing" ? [1000,15,1000,1000,1000,1000]
            : Array(repeating:1000,count:6)
        var game = HoldemGame(seed:42,startingStacks:stacks,button:fixture == "blind-all-in" ? 4 : 0)
        func step(_ action: PokerAction) {
            let state = game.snapshot
            try! game.act(action,seat:state.actor!,revision:state.revision)
        }
        for _ in 0..<(fixture == "blind-all-in" ? 5 : 3) { step(.call) }
        if fixture == "bet" {
            step(.call); step(.call); step(.check)
            for _ in 0..<5 { step(.check) }
        } else if fixture == "short-facing" {
            step(.call); step(.allIn)
            for _ in 0..<4 { step(.call) }
        }
        precondition(game.snapshot.actor == 0)
        return game
    }
}
#endif
