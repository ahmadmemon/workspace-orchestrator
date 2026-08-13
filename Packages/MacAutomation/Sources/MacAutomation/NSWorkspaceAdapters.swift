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

public struct NSWorkspaceFileOpener: FileOpening {
    public init() {}
    public func openFile(at url: URL, applicationBundleIdentifier: String?, revealInFinder: Bool) async throws {
        if revealInFinder { NSWorkspace.shared.activateFileViewerSelecting([url]); return }
        if let bundleIdentifier = applicationBundleIdentifier {
            guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { throw AutomationError.applicationNotFound(bundleIdentifier) }
            let configuration = NSWorkspace.OpenConfiguration()
            do { _ = try await NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) }
            catch { throw AutomationError.fileOpenFailed(error.localizedDescription) }
        } else if !NSWorkspace.shared.open(url) { throw AutomationError.fileOpenFailed(url.path) }
    }
}

public struct RunningApplicationDescriptor: Identifiable, Sendable, Equatable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public protocol RunningApplicationDiscovering {
    func discoverCapturableApplications(excludingBundleIdentifier: String?) -> [RunningApplicationDescriptor]
}

public struct NSWorkspaceRunningApplicationDiscovery: RunningApplicationDiscovering {
    public init() {}

    public func discoverCapturableApplications(excludingBundleIdentifier: String?) -> [RunningApplicationDescriptor] {
        NSWorkspace.shared.runningApplications.compactMap { application in
            guard application.activationPolicy == .regular,
                  let bundleIdentifier = application.bundleIdentifier,
                  bundleIdentifier != excludingBundleIdentifier,
                  !isSensitive(bundleIdentifier)
            else { return nil }

            return RunningApplicationDescriptor(
                id: bundleIdentifier,
                displayName: application.localizedName ?? bundleIdentifier
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func isSensitive(_ bundleIdentifier: String) -> Bool {
        let lowered = bundleIdentifier.lowercased()
        return ["1password", "lastpass", "bitwarden", "keepass", "keychainaccess"]
            .contains { lowered.contains($0) }
    }
}
