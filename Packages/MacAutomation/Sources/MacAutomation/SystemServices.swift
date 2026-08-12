import Foundation
import SceneCore
import ServiceManagement
import UserNotifications

public enum LaunchAtLoginStatus: String, Sendable { case enabled, disabled, requiresApproval, unavailable }

@MainActor
public protocol LaunchAtLoginManaging {
    func status() -> LaunchAtLoginStatus
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
public struct SystemLaunchAtLoginManager: LaunchAtLoginManaging {
    public init() {}
    public func status() -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
    public func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
    }
}

public protocol LocalNotificationManaging: Sendable {
    func permissionStatus() async -> PermissionState
    func requestPermission() async throws -> Bool
    func notify(run: SceneRunResult) async throws
}

public struct RunNotificationContent: Equatable, Sendable {
    public var title: String
    public var body: String

    public static func make(for run: SceneRunResult) -> RunNotificationContent? {
        switch run.status {
        case .ready:
            return .init(title: "\(safe(run.sceneName)) is ready", body: duration(run))
        case .readyWithWarnings:
            return .init(title: "\(safe(run.sceneName)) is ready with warnings", body: "\(run.warningCount) warning(s). \(duration(run))")
        case .failed:
            let failed = run.failedActionID.flatMap { id in run.actionRecords.first(where: { $0.id == id })?.name }
            return .init(title: "\(safe(run.sceneName)) failed", body: failed.map { "Blocked while starting \(safe($0))." } ?? "Open Run Details for the redacted failure summary.")
        default:
            return nil
        }
    }

    private static func safe(_ value: String) -> String {
        String(value.filter { !$0.isASCIIControl }.prefix(120))
    }
    private static func duration(_ run: SceneRunResult) -> String { run.duration.map { String(format: "Completed in %.1f seconds.", $0) } ?? "Workspace checks completed." }
}

public struct SystemLocalNotificationManager: LocalNotificationManaging {
    public init() {}
    public func permissionStatus() async -> PermissionState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
    }
    public func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
    public func notify(run: SceneRunResult) async throws {
        guard let summary = RunNotificationContent.make(for: run) else { return }
        let content = UNMutableNotificationContent()
        content.title = summary.title
        content.body = summary.body
        try await UNUserNotificationCenter.current().add(.init(identifier: run.id, content: content, trigger: nil))
    }
}

private extension Character {
    var isASCIIControl: Bool { unicodeScalars.allSatisfy { $0.value < 32 || $0.value == 127 } }
}
