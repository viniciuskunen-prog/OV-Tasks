// swift-tools-version: 5.9
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
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Security") // macOS Keychain for future explicit account connection
            ]
        ),
        .testTarget(
            name: "OVTasksCoreTests",
            dependencies: ["OVTasksCore"],
            path: "Tests/OVTasksCoreTests"
        )
    ]
)
