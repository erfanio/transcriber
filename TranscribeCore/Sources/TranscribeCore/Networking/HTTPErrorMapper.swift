import Foundation

/// Turns ElevenLabs-style error responses (`{"detail": {...}}` or `{"detail": "..."}`) into `TranscriptionError`.
public enum HTTPErrorMapper {
    public struct ErrorDetail: Sendable, Equatable {
        public var code: String?
        public var message: String
    }

    public static func map(status: Int, data: Data, retryAfterHeader: String? = nil) -> TranscriptionError {
        let detail = parseDetail(data)
        let message = detail.message
        let code = detail.code?.lowercased() ?? ""

        switch status {
        case 401:
            return .invalidAPIKey
        case 402:
            return .insufficientCredits
        case 403:
            return .forbidden(message)
        case 413:
            return .fileTooLarge
        case 400, 422:
            if code.contains("too_large") || message.lowercased().contains("too large") { return .fileTooLarge }
            return .badRequest(message)
        case 429:
            return .rateLimited(retryAfter: retryAfterHeader.flatMap { TimeInterval($0.trimmingCharacters(in: .whitespaces)) })
        case 500...599:
            return .serverError(status: status, message: message)
        default:
            return .unexpectedStatus(status, message)
        }
    }

    public static func parseDetail(_ data: Data) -> ErrorDetail {
        let fallback = String(data: data.prefix(300), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ErrorDetail(code: nil, message: fallback.isEmpty ? "No details" : fallback)
        }
        if let detail = object["detail"] as? [String: Any] {
            let message = (detail["message"] as? String) ?? fallback
            let code = (detail["code"] as? String) ?? (detail["status"] as? String)
            return ErrorDetail(code: code, message: message)
        }
        if let detail = object["detail"] as? String {
            return ErrorDetail(code: nil, message: detail)
        }
        if let message = object["message"] as? String {
            return ErrorDetail(code: object["code"] as? String, message: message)
        }
        return ErrorDetail(code: nil, message: fallback)
    }
}
