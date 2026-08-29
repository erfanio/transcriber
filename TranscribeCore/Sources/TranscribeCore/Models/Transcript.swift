import Foundation

/// One timed token from a speech-to-text provider.
public struct TranscriptWord: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case word
        case spacing
        case audioEvent
    }

    public var text: String
    public var kind: Kind
    public var start: TimeInterval
    public var end: TimeInterval
    public var speaker: String?

    public init(text: String, kind: Kind = .word, start: TimeInterval, end: TimeInterval, speaker: String? = nil) {
        self.text = text
        self.kind = kind
        self.start = start
        self.end = end
        self.speaker = speaker
    }
}

/// Provider-independent transcription result. `providerResponse` keeps the raw payload
/// so subtitles can be regenerated later without re-running the (paid) transcription.
public struct Transcript: Codable, Sendable, Equatable {
    public var providerID: String
    public var languageCode: String?
    public var text: String
    public var words: [TranscriptWord]
    public var audioDuration: TimeInterval?
    public var providerResponse: JSONValue?

    public init(
        providerID: String,
        languageCode: String? = nil,
        text: String,
        words: [TranscriptWord],
        audioDuration: TimeInterval? = nil,
        providerResponse: JSONValue? = nil
    ) {
        self.providerID = providerID
        self.languageCode = languageCode
        self.text = text
        self.words = words
        self.audioDuration = audioDuration
        self.providerResponse = providerResponse
    }
}

/// Loosely-typed JSON tree used to round-trip provider payloads verbatim.
public indirect enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
