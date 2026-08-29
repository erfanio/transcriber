import Foundation

/// Keeps API keys in owner-only files inside the app's sandbox container.
///
/// The keychain would be stronger, but ad-hoc-signed builds can only reach the legacy keychain,
/// which asks for the login password on every rebuild — unacceptable for a non-technical user.
nonisolated struct APIKeyStore: Sendable {
    enum Failure: Error, LocalizedError {
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let detail): return detail
            }
        }
    }

    func read(account: String) throws -> String? {
        let url = try fileURL(for: account)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw Failure.unreadable("The saved key is not valid text.")
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func write(_ secret: String, account: String) throws {
        let url = try fileURL(for: account)
        try Data(secret.utf8).write(to: url, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path(percentEncoded: false))
    }

    func delete(account: String) throws {
        let url = try fileURL(for: account)
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(for account: String) throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appending(path: "api-keys", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let safeName = account.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" }
        return directory.appending(path: String(safeName))
    }
}
