import Foundation
import Security

/// Generic-password storage. Prefers the data-protection keychain, but ad-hoc/unsigned builds can only use
/// the legacy file keychain, so every operation tries both.
nonisolated struct KeychainStore: Sendable {
    enum Failure: Error {
        case unexpectedData
        case status(OSStatus)
    }

    static let service = "io.erfan.transcribe-clips"

    func read(account: String) throws -> String? {
        for useDataProtection in [true, false] {
            var query = baseQuery(account: account, dataProtection: useDataProtection)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            switch status {
            case errSecSuccess:
                guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else { throw Failure.unexpectedData }
                return string
            case errSecItemNotFound, errSecMissingEntitlement, errSecParam, errSecNotAvailable:
                continue
            default:
                throw Failure.status(status)
            }
        }
        return nil
    }

    func write(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)
        var lastStatus = errSecSuccess
        for useDataProtection in [true, false] {
            lastStatus = upsert(data, account: account, dataProtection: useDataProtection)
            if lastStatus == errSecSuccess { return }
        }
        throw Failure.status(lastStatus)
    }

    func delete(account: String) throws {
        for useDataProtection in [true, false] {
            let status = SecItemDelete(baseQuery(account: account, dataProtection: useDataProtection) as CFDictionary)
            switch status {
            case errSecSuccess, errSecItemNotFound, errSecMissingEntitlement, errSecParam, errSecNotAvailable:
                continue
            default:
                throw Failure.status(status)
            }
        }
    }

    private func upsert(_ data: Data, account: String, dataProtection: Bool) -> OSStatus {
        let query = baseQuery(account: account, dataProtection: dataProtection)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return status }
        var add = query
        add[kSecValueData as String] = data
        if dataProtection {
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        }
        return SecItemAdd(add as CFDictionary, nil)
    }

    private func baseQuery(account: String, dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        if dataProtection {
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
