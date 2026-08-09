import AppKit
import Foundation

public struct NSWorkspaceApplicationOpener: ApplicationOpening {
    public init() {}

    public func openApplication(bundleIdentifier: String) async throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AutomationError.applicationNotFound(bundleIdentifier)
        }
        do {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            throw AutomationError.applicationLaunchFailed(error.localizedDescription)
        }
    }
}

public struct NSWorkspaceURLOpener: URLOpening {
    public init() {}

    public func openURL(_ url: URL) async throws {
        guard NSWorkspace.shared.open(url) else {
            throw AutomationError.urlOpenFailed(url.absoluteString)
        }
    }
}
