// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OVTasks",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OVTasksCore", targets: ["OVTasksCore"])
    ],
    targets: [
        .target(
            name: "OVTasksCore",
            path: "Sources/OVTasksCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "OVTasksCoreTests",
            dependencies: ["OVTasksCore"],
            path: "Tests/OVTasksCoreTests"
        )
    ],
    // Explicitly resolve the PackageDescription 6.0+ initializer (swiftLanguageModes)
    // while compiling the existing sources in the Swift 5 language compatibility mode.
    swiftLanguageModes: [.v5]
)
