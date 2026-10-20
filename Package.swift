// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PokerDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PokerCore", targets: ["PokerCore"])],
    targets: [
        .target(name: "PokerCore"),
        .executableTarget(name: "PokerCoreChecks", dependencies: ["PokerCore"], path: "Tests/PokerCoreTests"),
        .testTarget(name: "PokerNativeTests", dependencies: ["PokerCore"], path: "Tests/NativeUnitTests")
    ]
)
