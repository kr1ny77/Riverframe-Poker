import SwiftUI

@main
struct PokerTrainerApp: App {
    @StateObject private var game = GameViewModel()
    @StateObject private var practice = PracticeStore()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(game)
                .environmentObject(practice)

        }
    }
}
