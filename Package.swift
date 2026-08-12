// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WorkspaceOrchestrator",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SceneCore", targets: ["SceneCore"]),
        .library(name: "OrchestrationEngine", targets: ["OrchestrationEngine"]),
        .library(name: "MacAutomation", targets: ["MacAutomation"]),
        .library(name: "WorkspaceIntegrations", targets: ["WorkspaceIntegrations"])
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
        .target(
            name: "WorkspaceIntegrations",
            dependencies: ["SceneCore", "OrchestrationEngine", "MacAutomation"],
            path: "Packages/WorkspaceIntegrations/Sources/WorkspaceIntegrations"
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
        ),
        .testTarget(
            name: "WorkspaceIntegrationsTests",
            dependencies: ["WorkspaceIntegrations", "SceneCore", "MacAutomation"],
            path: "Tests/WorkspaceIntegrationsTests"
        )
    ]
)
