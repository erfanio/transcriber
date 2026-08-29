import Foundation
import TranscribeCore

nonisolated struct ProviderInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let needsAPIKey: Bool
}

/// The one place that knows about concrete backends. Add a new service here and it appears in Settings.
nonisolated enum ProviderFactory {
    static let elevenLabsID = "elevenlabs-scribe-v2"

    static var available: [ProviderInfo] {
        var list = [ProviderInfo(id: elevenLabsID, name: "ElevenLabs Scribe v2", needsAPIKey: true)]
        #if DEBUG
        list.append(ProviderInfo(id: MockTranscriptionProvider.providerID, name: "Mock (offline test)", needsAPIKey: false))
        #endif
        return list
    }

    static func info(for id: String) -> ProviderInfo? {
        available.first { $0.id == id }
    }

    static func make(_ config: RunConfiguration) throws -> any TranscriptionProvider {
        switch config.providerID {
        case MockTranscriptionProvider.providerID:
            return MockTranscriptionProvider()
        case elevenLabsID:
            guard let key = config.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
                throw TranscriptionError.missingAPIKey
            }
            throw TranscriptionError.badRequest("ElevenLabs support is not wired up yet")
        default:
            throw TranscriptionError.badRequest("Unknown transcription service: \(config.providerID)")
        }
    }
}
