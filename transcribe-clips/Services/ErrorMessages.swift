import Foundation
import TranscribeCore

enum ErrorMessages {
    static func text(for error: TranscriptionError) -> String {
        switch error {
        case .missingAPIKey:
            return String(localized: "Add your API key in Settings first.")
        case .invalidAPIKey:
            return String(localized: "The API key was rejected. Check it in Settings.")
        case .forbidden(let detail):
            return String(localized: "The service refused this request: \(detail)")
        case .insufficientCredits:
            return String(localized: "Your account has run out of credits.")
        case .fileTooLarge:
            return String(localized: "This clip is too large for the service.")
        case .badRequest(let detail):
            return String(localized: "The service could not process this clip: \(detail)")
        case .rateLimited:
            return String(localized: "The service is busy. Try again in a few minutes.")
        case .serverError(let status, _):
            return String(localized: "The service had a problem (error \(status)). Try again later.")
        case .network(_, let detail):
            return String(localized: "Network problem: \(detail)")
        case .decoding:
            return String(localized: "The service sent an unexpected reply.")
        case .unexpectedStatus(let status, _):
            return String(localized: "Unexpected reply from the service (\(status)).")
        }
    }

    static func text(for error: AudioExtractor.Failure) -> String {
        switch error {
        case .unreadable:
            return String(localized: "Can't read this file. Export it from DaVinci Resolve as a MOV or MP4 first.")
        case .noAudioTrack:
            return String(localized: "This clip has no audio track.")
        case .exportFailed(let detail):
            return String(localized: "Could not extract the audio: \(detail)")
        }
    }
}
