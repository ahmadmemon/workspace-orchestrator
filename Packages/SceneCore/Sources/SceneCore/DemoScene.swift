import Foundation

public extension Scene {
    static func demo(now: Date = Date()) -> Scene {
        Scene(
            name: "Workspace Orchestrator Demo",
            description: "A harmless demonstration scene. Running it opens TextEdit, opens example.com, and prints a completion message.",
            actions: [
                .openApplication(.init(id: "demo-open-textedit", bundleIdentifier: "com.apple.TextEdit")),
                .openURL(.init(id: "demo-open-url", url: "https://example.com", configuration: .init(dependencies: ["demo-open-textedit"], idempotencyPolicy: .oncePerRun))),
                .runProcess(.init(
                    id: "demo-run-printf",
                    executable: "/usr/bin/printf",
                    arguments: ["Workspace Orchestrator demo completed.\n"],
                    timeoutSeconds: 10,
                    configuration: .init(dependencies: ["demo-open-url"])
                ))
            ],
            maximumConcurrency: 1,
            createdAt: now,
            updatedAt: now
        )
    }
}
