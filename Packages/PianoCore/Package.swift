// swift-tools-version:6.0
// Swift 6 language mode (strict concurrency) for the core. Tests: swift test
import PackageDescription

let package = Package(
    name: "PianoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PianoCore", targets: ["PianoCore"]),
    ],
    targets: [
        .target(name: "PianoCore"),
        .testTarget(name: "PianoCoreTests", dependencies: ["PianoCore"]),
        // Writes the bundled sample songs: swift run write-samples <dir>
        .executableTarget(name: "write-samples", dependencies: ["PianoCore"]),
    ]
)
