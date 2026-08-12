import Foundation

public enum ActivationAction: String, Codable, CaseIterable, Sendable { case commandPalette, scenePicker, favoriteWithConfirmation, favoriteImmediately }
public struct HotKeyConfiguration: Codable, Equatable, Sendable {
    public var keyCode: UInt32; public var modifiers: UInt32; public var enabled: Bool
    public init(keyCode: UInt32 = 49, modifiers: UInt32 = 2_048 | 512, enabled: Bool = true) { self.keyCode = keyCode; self.modifiers = modifiers; self.enabled = enabled }
}
public struct ClapConfiguration: Codable, Equatable, Sendable {
    public var enabled: Bool; public var sensitivity: Double; public var minimumInterval: Double; public var maximumInterval: Double; public var cooldown: Double; public var action: ActivationAction
    public init(enabled: Bool = false, sensitivity: Double = 0.65, minimumInterval: Double = 0.12, maximumInterval: Double = 0.65, cooldown: Double = 2.5, action: ActivationAction = .scenePicker) { self.enabled = enabled; self.sensitivity = sensitivity; self.minimumInterval = minimumInterval; self.maximumInterval = maximumInterval; self.cooldown = cooldown; self.action = action }
}
public struct VoiceConfiguration: Codable, Equatable, Sendable {
    public var enabled: Bool; public var localeIdentifier: String; public var activationPhrase: String; public var timeoutSeconds: Double
    public init(enabled: Bool = false, localeIdentifier: String = Locale.current.identifier, activationPhrase: String = "Workspace online", timeoutSeconds: Double = 8) { self.enabled = enabled; self.localeIdentifier = localeIdentifier; self.activationPhrase = activationPhrase; self.timeoutSeconds = timeoutSeconds }
}
