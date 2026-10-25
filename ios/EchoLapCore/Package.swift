// swift-tools-version:5.9
// EchoLapCore: the whole game without any UI. Tracks, physics, echoes, the robot driver, progression and rewards.
// Builds and tests on Linux (tools/swift/linux-swift.sh) and on a Mac (`swift test`).
import PackageDescription

let package = Package(
    name: "EchoLapCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "EchoLapCore", targets: ["EchoLapCore"])],
    targets: [
        .target(name: "EchoLapCore"),
        .testTarget(name: "EchoLapCoreTests", dependencies: ["EchoLapCore"]),
    ]
)
