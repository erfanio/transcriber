import Foundation

public struct TranscriptionOptions: Sendable, Equatable {
    /// ISO 639 code (e.g. "fas" for Persian); nil lets the provider auto-detect.
    public var languageCode: String?
    public var diarize: Bool
    public var numSpeakers: Int?
    /// Names and domain terms that help the recogniser (character names, places).
    public var keyterms: [String]
    public var tagAudioEvents: Bool

    public init(
        languageCode: String? = "fas",
        diarize: Bool = false,
        numSpeakers: Int? = nil,
        keyterms: [String] = [],
        tagAudioEvents: Bool = false
    ) {
        self.languageCode = languageCode
        self.diarize = diarize
        self.numSpeakers = numSpeakers
        self.keyterms = keyterms
        self.tagAudioEvents = tagAudioEvents
    }
}
