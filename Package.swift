// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WorkspaceOrchestrator",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SceneCore", targets: ["SceneCore"]),
        .library(name: "OrchestrationEngine", targets: ["OrchestrationEngine"]),
        .library(name: "MacAutomation", targets: ["MacAutomation"])
    ],
    targets: [
        .target(
            name: "SceneCore",
            path: "Packages/SceneCore/Sources/SceneCore"
        ),
        .target(
            name: "OrchestrationEngine",
            dependencies: ["SceneCore"],
            path: "Packages/OrchestrationEngine/Sources/OrchestrationEngine"
        ),
        .target(
            name: "MacAutomation",
            dependencies: ["SceneCore", "OrchestrationEngine"],
            path: "Packages/MacAutomation/Sources/MacAutomation"
        ),
        .testTarget(
            name: "OrchestrationEngineTests",
            dependencies: ["OrchestrationEngine", "SceneCore"],
            path: "Tests/OrchestrationEngineTests"
        ),
        .testTarget(
            name: "SceneCoreTests",
            dependencies: ["SceneCore"],
            path: "Tests/SceneCoreTests"
        ),
        .testTarget(
            name: "MacAutomationTests",
            dependencies: ["MacAutomation", "SceneCore"],
            path: "Tests/MacAutomationTests"
        )
    ]
)
