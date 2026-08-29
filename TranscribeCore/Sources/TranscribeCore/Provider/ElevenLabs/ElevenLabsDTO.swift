import Foundation

enum ElevenLabsDTO {
    struct SpeechToTextResponse: Decodable {
        struct Word: Decodable {
            var text: String
            var type: String
            var start: Double?
            var end: Double?
            var speakerID: String?

            enum CodingKeys: String, CodingKey {
                case text, type, start, end
                case speakerID = "speaker_id"
            }
        }

        var languageCode: String?
        var text: String
        var words: [Word]?
        var transcriptionID: String?
        var audioDurationSecs: Double?

        enum CodingKeys: String, CodingKey {
            case text, words
            case languageCode = "language_code"
            case transcriptionID = "transcription_id"
            case audioDurationSecs = "audio_duration_secs"
        }
    }

    struct UserResponse: Decodable {
        struct Subscription: Decodable {
            var tier: String?
            var characterCount: Int?
            var characterLimit: Int?
            var status: String?

            enum CodingKeys: String, CodingKey {
                case tier, status
                case characterCount = "character_count"
                case characterLimit = "character_limit"
            }
        }

        var subscription: Subscription?
        var firstName: String?

        enum CodingKeys: String, CodingKey {
            case subscription
            case firstName = "first_name"
        }
    }

    static func transcript(from data: Data, providerID: String) throws -> Transcript {
        let response: SpeechToTextResponse
        do {
            response = try JSONDecoder().decode(SpeechToTextResponse.self, from: data)
        } catch {
            throw TranscriptionError.decoding(String(describing: error))
        }
        let raw = try? JSONDecoder().decode(JSONValue.self, from: data)
        return Transcript(
            providerID: providerID,
            languageCode: response.languageCode,
            text: response.text,
            words: words(from: response.words ?? []),
            audioDuration: response.audioDurationSecs,
            providerResponse: raw
        )
    }

    /// Drops spacing tokens and glues punctuation-only tokens onto the preceding word.
    static func words(from dtoWords: [SpeechToTextResponse.Word]) -> [TranscriptWord] {
        var result: [TranscriptWord] = []
        var lastEnd: TimeInterval = 0
        for word in dtoWords {
            let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let kind: TranscriptWord.Kind
            switch word.type {
            case "word": kind = .word
            case "audio_event": kind = .audioEvent
            default: continue
            }
            let start = word.start ?? lastEnd
            let end = max(word.end ?? start, start)
            lastEnd = end

            let isPunctuationOnly = text.allSatisfy { $0.isPunctuation || $0.isSymbol }
            if kind == .word, isPunctuationOnly, let index = result.indices.last, result[index].kind == .word {
                result[index].text += text
                result[index].end = max(result[index].end, end)
                continue
            }
            result.append(TranscriptWord(text: text, kind: kind, start: start, end: end, speaker: word.speakerID))
        }
        return result
    }
}
