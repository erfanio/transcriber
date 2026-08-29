import Foundation

public enum TranscriptionError: Error, Sendable, Equatable {
    case missingAPIKey
    case invalidAPIKey
    /// The key is valid but lacks a permission (ElevenLabs: `missing_permissions`).
    case missingPermissions(String)
    /// 401 for a reason other than a bad key (e.g. ElevenLabs `detected_unusual_activity`); message is the server's.
    case unauthorized(String)
    case forbidden(String)
    case insufficientCredits
    case fileTooLarge
    case badRequest(String)
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(status: Int, message: String)
    case network(code: URLError.Code, message: String)
    case decoding(String)
    case unexpectedStatus(Int, String)

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError:
            return true
        case .network(let code, _):
            return [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet, .dnsLookupFailed]
                .contains(code)
        default:
            return false
        }
    }

    /// English fallback text; the app maps cases to localized strings.
    public var message: String {
        switch self {
        case .missingAPIKey: return "No API key configured."
        case .invalidAPIKey: return "Invalid API key."
        case .missingPermissions(let m): return "The API key lacks a required permission: \(m)"
        case .unauthorized(let m): return "Not authorized: \(m)"
        case .forbidden(let m): return "Not permitted: \(m)"
        case .insufficientCredits: return "Not enough credits on this account."
        case .fileTooLarge: return "The file is too large for this service."
        case .badRequest(let m): return "The service rejected the request: \(m)"
        case .rateLimited: return "Rate limited by the service."
        case .serverError(let status, let m): return "Service error (\(status)): \(m)"
        case .network(_, let m): return "Network error: \(m)"
        case .decoding(let m): return "Could not read the service response: \(m)"
        case .unexpectedStatus(let status, let m): return "Unexpected response (\(status)): \(m)"
        }
    }
}
