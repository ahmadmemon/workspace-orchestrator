import Carbon
import Foundation

@MainActor
public final class GlobalHotKeyController {
    private var reference: EventHotKeyRef?; private var handler: EventHandlerRef?; private var callback: (() -> Void)?
    public init() {}
    deinit { if let reference { UnregisterEventHotKey(reference) }; if let handler { RemoveEventHandler(handler) } }
    public func register(_ configuration: HotKeyConfiguration, callback: @escaping () -> Void) throws {
        unregister(); guard configuration.enabled else { return }; self.callback = callback
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in guard let context else { return noErr }; let controller = Unmanaged<GlobalHotKeyController>.fromOpaque(context).takeUnretainedValue(); Task { @MainActor in controller.callback?() }; return noErr }, 1, &eventType, pointer, &handler)
        guard status == noErr else { throw HotKeyError.registration(status) }
        let id = EventHotKeyID(signature: OSType(0x574F524B), id: 1)
        let registerStatus = RegisterEventHotKey(configuration.keyCode, configuration.modifiers, id, GetApplicationEventTarget(), 0, &reference)
        guard registerStatus == noErr else { unregister(); throw HotKeyError.conflict(registerStatus) }
    }
    public func unregister() { if let reference { UnregisterEventHotKey(reference) }; reference = nil; if let handler { RemoveEventHandler(handler) }; handler = nil; callback = nil }
    public enum HotKeyError: LocalizedError { case registration(OSStatus), conflict(OSStatus); public var errorDescription: String? { switch self { case .registration(let status): "Global shortcut handler could not be installed (\(status))."; case .conflict: "The global shortcut is unavailable, likely because another application uses it." } } }
}
