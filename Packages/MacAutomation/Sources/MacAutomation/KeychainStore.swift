import Foundation
import Security

public protocol KeychainStoring: Sendable {
    func create(id: String, value: Data) async throws
    func update(id: String, value: Data) async throws
    func read(id: String) async throws -> Data
    func delete(id: String) async throws
    func listIDs() async throws -> [String]
}

public extension KeychainStoring { func listIDs() async throws -> [String] { [] } }

public enum KeychainStoreError: LocalizedError, Equatable {
    case duplicate; case notFound; case unexpectedStatus(Int32)
    public var errorDescription: String? { switch self { case .duplicate: "A Keychain secret with this identifier already exists."; case .notFound: "The referenced Keychain secret was not found."; case .unexpectedStatus(let status): "Keychain operation failed with status \(status)." } }
}

public struct SystemKeychainStore: KeychainStoring {
    private let service: String
    public init(service: String = "com.ahmadmemon.WorkspaceOrchestrator.secrets") { self.service = service }
    public func create(id: String, value: Data) async throws { var query = base(id); query[kSecValueData as String] = value; try check(SecItemAdd(query as CFDictionary, nil)) }
    public func update(id: String, value: Data) async throws { let status = SecItemUpdate(base(id) as CFDictionary, [kSecValueData as String: value] as CFDictionary); try check(status) }
    public func read(id: String) async throws -> Data { var query = base(id); query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne; var item: CFTypeRef?; try check(SecItemCopyMatching(query as CFDictionary, &item)); guard let data = item as? Data else { throw KeychainStoreError.notFound }; return data }
    public func delete(id: String) async throws { let status = SecItemDelete(base(id) as CFDictionary); if status != errSecItemNotFound { try check(status) } }
    public func listIDs() async throws -> [String] {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound { return [] }
        try check(status)
        let dictionaries = items as? [[String: Any]] ?? []
        return dictionaries.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    }
    private func base(_ id: String) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] }
    private func check(_ status: OSStatus) throws { switch status { case errSecSuccess: return; case errSecDuplicateItem: throw KeychainStoreError.duplicate; case errSecItemNotFound: throw KeychainStoreError.notFound; default: throw KeychainStoreError.unexpectedStatus(status) } }
}
