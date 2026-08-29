import Foundation
import Security

nonisolated struct KeychainStore: Sendable {
    enum Failure: Error {
        case unexpectedData
        case status(OSStatus)
    }

    static let service = "io.erfan.transcribe-clips"

    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = withFallback { SecItemCopyMatching(applying($0, to: query) as CFDictionary, &result) }
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else { throw Failure.unexpectedData }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw Failure.status(status)
        }
    }

    func write(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)
        let query = baseQuery(account: account)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = withFallback { SecItemUpdate(applying($0, to: query) as CFDictionary, update as CFDictionary) }
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = withFallback { SecItemAdd(applying($0, to: add) as CFDictionary, nil) }
        }
        guard status == errSecSuccess else { throw Failure.status(status) }
    }

    func delete(account: String) throws {
        let status = withFallback { SecItemDelete(applying($0, to: baseQuery(account: account)) as CFDictionary) }
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.status(status) }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
    }

    // The data-protection keychain needs a real signing identity; ad-hoc builds fall back to the legacy keychain.
    private func withFallback(_ operation: (_ useDataProtection: Bool) -> OSStatus) -> OSStatus {
        let status = operation(true)
        if status == errSecMissingEntitlement || status == errSecParam {
            return operation(false)
        }
        return status
    }

    private func applying(_ useDataProtection: Bool, to query: [String: Any]) -> [String: Any] {
        var query = query
        if useDataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }
}

extension KeychainStore.Failure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return String(localized: "The stored key could not be read.")
        case .status(let status):
            return (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)"
        }
    }
}
