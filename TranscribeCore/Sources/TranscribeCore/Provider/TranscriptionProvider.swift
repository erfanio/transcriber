import Foundation

public enum TranscriptionProgress: Sendable, Equatable {
    case uploading(fraction: Double)
    case processing
    case waitingToRetry(seconds: TimeInterval)
}

/// A speech-to-text backend. Implementations must be safe to call concurrently for different files.
public protocol TranscriptionProvider: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// Cheap check that the configured credentials work; returns a short human-readable account summary.
    func validateCredentials() async throws -> String

    func transcribe(
        audioFileURL: URL,
        options: TranscriptionOptions,
        progress: @Sendable @escaping (TranscriptionProgress) -> Void
    ) async throws -> Transcript
}
