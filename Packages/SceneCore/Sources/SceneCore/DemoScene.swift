import Foundation

public extension Scene {
    static func demo(now: Date = Date()) -> Scene {
        Scene(
            name: "Workspace Orchestrator Demo",
            description: "A harmless demonstration scene. Running it opens TextEdit, opens example.com, and prints a completion message.",
            actions: [
                .openApplication(.init(bundleIdentifier: "com.apple.TextEdit")),
                .openURL(.init(url: "https://example.com")),
                .runProcess(.init(
                    executable: "/usr/bin/printf",
                    arguments: ["Workspace Orchestrator demo completed.\n"],
                    timeoutSeconds: 10
                ))
            ],
            createdAt: now,
            updatedAt: now
        )
    }
}
