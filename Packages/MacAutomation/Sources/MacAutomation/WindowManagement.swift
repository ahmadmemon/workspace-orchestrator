import AppKit
import ApplicationServices
import Foundation
import SceneCore

public enum PermissionState: String, Codable, Sendable { case notDetermined, denied, granted, unavailable }
public protocol AccessibilityPermissionManaging: Sendable {
    func status() -> PermissionState
    func requestExplicitly() -> PermissionState
    func openSystemSettings() async
}
public struct SystemAccessibilityPermissionManager: AccessibilityPermissionManaging {
    public init() {}
    public func status() -> PermissionState { AXIsProcessTrusted() ? .granted : .denied }
    public func requestExplicitly() -> PermissionState { let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary; return AXIsProcessTrustedWithOptions(options) ? .granted : .denied }
    public func openSystemSettings() async { if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) } }
}

public struct DisplayGeometry: Codable, Equatable, Identifiable, Sendable {
    public var id: String; public var frame: CGRect; public var visibleFrame: CGRect; public var scaleFactor: Double; public var isMain: Bool
    public init(id: String, frame: CGRect, visibleFrame: CGRect, scaleFactor: Double = 1, isMain: Bool = false) { self.id = id; self.frame = frame; self.visibleFrame = visibleFrame; self.scaleFactor = scaleFactor; self.isMain = isMain }
}
public struct CapturedWindow: Codable, Equatable, Identifiable, Sendable {
    public var id: String; public var bundleIdentifier: String; public var applicationName: String; public var title: String?; public var placement: WindowPlacement; public var matchingConfidence: Double
    public init(id: String = UUID().uuidString, bundleIdentifier: String, applicationName: String, title: String?, placement: WindowPlacement, matchingConfidence: Double) { self.id = id; self.bundleIdentifier = bundleIdentifier; self.applicationName = applicationName; self.title = title; self.placement = placement; self.matchingConfidence = matchingConfidence }
}
public struct WindowRestorationResult: Equatable, Sendable { public var applied: [String]; public var unmatched: [String]; public var warnings: [String] }

public enum WindowLayoutMath {
    public static func normalize(_ frame: CGRect, in display: CGRect) -> NormalizedFrame { .init(x: (frame.minX - display.minX) / display.width, y: (frame.minY - display.minY) / display.height, width: frame.width / display.width, height: frame.height / display.height) }
    public static func denormalize(_ frame: NormalizedFrame, in display: CGRect) -> CGRect { .init(x: display.minX + frame.x * display.width, y: display.minY + frame.y * display.height, width: frame.width * display.width, height: frame.height * display.height) }
    public static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect { let width = min(max(120, frame.width), visible.width); let height = min(max(80, frame.height), visible.height); return .init(x: min(max(frame.minX, visible.minX), visible.maxX - width), y: min(max(frame.minY, visible.minY), visible.maxY - height), width: width, height: height) }
    public static func display(for identifier: String?, among displays: [DisplayGeometry]) -> DisplayGeometry? { if let identifier, let exact = displays.first(where: { $0.id == identifier }) { return exact }; return displays.first(where: \.isMain) ?? displays.first }
}

public protocol WindowLayoutControlling: Sendable {
    func displays() -> [DisplayGeometry]
    func capture(bundleIdentifiers: Set<String>) async throws -> [CapturedWindow]
    func apply(_ action: WindowLayoutAction) async throws -> WindowRestorationResult
}
public enum WindowManagementError: LocalizedError { case permissionRequired; case noDisplays; public var errorDescription: String? { switch self { case .permissionRequired: "Accessibility permission is required for reviewed window capture or restoration."; case .noDisplays: "No usable display is available." } } }

public struct AXWindowLayoutController: WindowLayoutControlling {
    private let permission: any AccessibilityPermissionManaging
    public init(permission: any AccessibilityPermissionManaging = SystemAccessibilityPermissionManager()) { self.permission = permission }
    public func displays() -> [DisplayGeometry] { NSScreen.screens.map { screen in let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber; return .init(id: number?.stringValue ?? screen.localizedName, frame: screen.frame, visibleFrame: screen.visibleFrame, scaleFactor: screen.backingScaleFactor, isMain: screen == NSScreen.main) } }
    public func capture(bundleIdentifiers: Set<String>) async throws -> [CapturedWindow] {
        guard permission.status() == .granted else { throw WindowManagementError.permissionRequired }
        let displayValues = displays(); guard !displayValues.isEmpty else { throw WindowManagementError.noDisplays }
        var captured: [CapturedWindow] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.bundleIdentifier.map(bundleIdentifiers.contains) == true {
            guard let bundleID = app.bundleIdentifier else { continue }; let element = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success, let windows = value as? [AXUIElement] else { continue }
            for window in windows {
                guard let frame = frame(of: window), let display = displayValues.first(where: { $0.frame.intersects(frame) }) ?? displayValues.first else { continue }
                let title = stringAttribute(kAXTitleAttribute, from: window); let rule: WindowMatchRule = title?.isEmpty == false ? .exactTitle : .appFrontmost
                let placement = WindowPlacement(bundleIdentifier: bundleID, matchRule: rule, title: title, frame: WindowLayoutMath.normalize(frame, in: display.frame), displayIdentifier: display.id, minimized: boolAttribute(kAXMinimizedAttribute, from: window) ?? false)
                captured.append(.init(bundleIdentifier: bundleID, applicationName: app.localizedName ?? bundleID, title: title, placement: placement, matchingConfidence: rule == .exactTitle ? 0.9 : 0.6))
            }
        }
        return captured
    }
    public func apply(_ action: WindowLayoutAction) async throws -> WindowRestorationResult {
        guard permission.status() == .granted else { throw WindowManagementError.permissionRequired }
        let displayValues = displays(); guard !displayValues.isEmpty else { throw WindowManagementError.noDisplays }
        var applied: [String] = [], unmatched: [String] = [], warnings: [String] = []
        for placement in action.placements {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: placement.bundleIdentifier).first else { unmatched.append(placement.id); continue }
            let element = AXUIElementCreateApplication(app.processIdentifier); var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success, let windows = value as? [AXUIElement], let window = match(placement, windows: windows) else { unmatched.append(placement.id); continue }
            guard let display = WindowLayoutMath.display(for: placement.displayIdentifier, among: displayValues) else { unmatched.append(placement.id); continue }
            if placement.displayIdentifier != nil && display.id != placement.displayIdentifier { warnings.append("Display \(placement.displayIdentifier!) was unavailable; used \(display.id).") }
            let target = WindowLayoutMath.clamp(WindowLayoutMath.denormalize(placement.frame, in: display.frame), to: display.visibleFrame)
            var origin = target.origin, size = target.size
            guard let position = AXValueCreate(.cgPoint, &origin), let dimensions = AXValueCreate(.cgSize, &size), AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position) == .success, AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions) == .success else { unmatched.append(placement.id); continue }
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, placement.minimized ? kCFBooleanTrue : kCFBooleanFalse); applied.append(placement.id)
        }
        return .init(applied: applied, unmatched: unmatched, warnings: warnings)
    }
    private func match(_ placement: WindowPlacement, windows: [AXUIElement]) -> AXUIElement? { switch placement.matchRule { case .appFrontmost: windows.first; case .exactTitle: windows.first { stringAttribute(kAXTitleAttribute, from: $0) == placement.title }; case .titleContains: windows.first { guard let expected = placement.title else { return false }; return stringAttribute(kAXTitleAttribute, from: $0)?.localizedCaseInsensitiveContains(expected) == true } } }
    private func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        let position = unsafeBitCast(positionValue, to: AXValue.self), dimensions = unsafeBitCast(sizeValue, to: AXValue.self)
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(dimensions, .cgSize, &size) else { return nil }
        return .init(origin: point, size: size)
    }
    private func stringAttribute(_ name: String, from element: AXUIElement) -> String? { var value: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }; return value as? String }
    private func boolAttribute(_ name: String, from element: AXUIElement) -> Bool? { var value: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }; return value as? Bool }
}
