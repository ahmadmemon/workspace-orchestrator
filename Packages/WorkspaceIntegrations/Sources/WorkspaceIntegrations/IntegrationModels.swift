import AppKit
import Foundation
import MacAutomation
import OrchestrationEngine
import SceneCore

public enum IntegrationKind: String, Codable, CaseIterable, Sendable {
    case visualStudioCode, visualStudioCodeInsiders, cursor, vscodium, terminal, iTerm2, tmux
    case docker, dockerDesktop, safari, chrome, firefox, arc, shortcuts
}

public struct IntegrationDescriptor: Codable, Equatable, Identifiable, Sendable {
    public var id: IntegrationKind; public var displayName: String; public var installed: Bool
    public var version: String?; public var path: String?; public var requiredPermission: String?; public var privacyNote: String
    public init(id: IntegrationKind, displayName: String, installed: Bool, version: String? = nil, path: String? = nil, requiredPermission: String? = nil, privacyNote: String) { self.id = id; self.displayName = displayName; self.installed = installed; self.version = version; self.path = path; self.requiredPermission = requiredPermission; self.privacyNote = privacyNote }
}

public protocol IntegrationDiscovering: Sendable { func discover() async -> [IntegrationDescriptor] }

public struct NativeIntegrationDiscovery: IntegrationDiscovering {
    public init() {}
    public func discover() async -> [IntegrationDescriptor] {
        let apps: [(IntegrationKind, String, String)] = [
            (.visualStudioCode, "Visual Studio Code", "com.microsoft.VSCode"), (.visualStudioCodeInsiders, "Visual Studio Code Insiders", "com.microsoft.VSCodeInsiders"),
            (.cursor, "Cursor", "com.todesktop.230313mzl4w4u92"), (.vscodium, "VSCodium", "com.vscodium"), (.terminal, "Terminal", "com.apple.Terminal"),
            (.iTerm2, "iTerm2", "com.googlecode.iterm2"), (.dockerDesktop, "Docker Desktop", "com.docker.docker"), (.safari, "Safari", "com.apple.Safari"),
            (.chrome, "Google Chrome", "com.google.Chrome"), (.firefox, "Firefox", "org.mozilla.firefox"), (.arc, "Arc", "company.thebrowser.Browser")
        ]
        var result = apps.map { kind, name, bundleID -> IntegrationDescriptor in
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            let bundle = url.flatMap(Bundle.init(url:)); let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            return .init(id: kind, displayName: name, installed: url != nil, version: version, path: url?.path, privacyNote: "Workspace Orchestrator opens only explicitly configured workspace items.")
        }
        let tools: [(IntegrationKind, String, [String])] = [(.tmux, "tmux", ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"]), (.docker, "Docker CLI", ["/usr/local/bin/docker", "/opt/homebrew/bin/docker"]), (.shortcuts, "macOS Shortcuts", ["/usr/bin/shortcuts"])]
        result += tools.map { kind, name, candidates in let path = candidates.first(where: FileManager.default.isExecutableFile(atPath:)); return .init(id: kind, displayName: name, installed: path != nil, path: path, privacyNote: "Commands are generated from typed fields and run without a shell.") }
        return result.sorted { $0.displayName < $1.displayName }
    }
}

public protocol IntegrationExecutableLocating: Sendable { func executable(for kind: IntegrationKind) -> String? }
public struct StandardIntegrationExecutableLocator: IntegrationExecutableLocating {
    public init() {}
    public func executable(for kind: IntegrationKind) -> String? {
        let candidates: [String]
        switch kind { case .tmux: candidates = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux"]; case .docker: candidates = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker"]; case .shortcuts: candidates = ["/usr/bin/shortcuts"]; default: return nil }
        return candidates.first(where: FileManager.default.isExecutableFile(atPath:))
    }
}
