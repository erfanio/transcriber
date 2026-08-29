import Foundation
import Observation
import TranscribeCore

@Observable
final class AppSettings {
    struct Language {
        let code: String
        let name: String
    }

    static let languages: [Language] = [
        Language(code: "", name: String(localized: "Detect automatically")),
        Language(code: "fas", name: String(localized: "Persian")),
        Language(code: "eng", name: String(localized: "English")),
        Language(code: "ara", name: String(localized: "Arabic")),
        Language(code: "tur", name: String(localized: "Turkish")),
        Language(code: "fra", name: String(localized: "French")),
        Language(code: "deu", name: String(localized: "German")),
        Language(code: "spa", name: String(localized: "Spanish")),
    ]

    private let defaults: UserDefaults

    var providerID: String { didSet { defaults.set(providerID, forKey: "providerID") } }
    var languageCode: String { didSet { defaults.set(languageCode, forKey: "languageCode") } }
    var maxConcurrent: Int { didSet { defaults.set(maxConcurrent, forKey: "maxConcurrent") } }
    var diarize: Bool { didSet { defaults.set(diarize, forKey: "diarize") } }
    var colorSpeakers: Bool { didSet { defaults.set(colorSpeakers, forKey: "colorSpeakers") } }
    var keytermsText: String { didSet { defaults.set(keytermsText, forKey: "keytermsText") } }
    var maxCharsPerLine: Int { didSet { defaults.set(maxCharsPerLine, forKey: "maxCharsPerLine") } }
    var maxCueDuration: Double { didSet { defaults.set(maxCueDuration, forKey: "maxCueDuration") } }
    var saveRawTranscript: Bool { didSet { defaults.set(saveRawTranscript, forKey: "saveRawTranscript") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        providerID = defaults.string(forKey: "providerID") ?? ProviderFactory.elevenLabsID
        languageCode = defaults.string(forKey: "languageCode") ?? "fas"
        maxConcurrent = defaults.object(forKey: "maxConcurrent") as? Int ?? 2
        diarize = defaults.object(forKey: "diarize") as? Bool ?? true
        colorSpeakers = defaults.bool(forKey: "colorSpeakers")
        keytermsText = defaults.string(forKey: "keytermsText") ?? ""
        maxCharsPerLine = defaults.object(forKey: "maxCharsPerLine") as? Int ?? 42
        maxCueDuration = defaults.object(forKey: "maxCueDuration") as? Double ?? 6.0
        saveRawTranscript = defaults.object(forKey: "saveRawTranscript") as? Bool ?? true
        if ProviderFactory.info(for: providerID) == nil {
            providerID = ProviderFactory.elevenLabsID
        }
    }

    var keyterms: [String] {
        keytermsText
            .split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func runConfiguration(apiKey: String?) -> RunConfiguration {
        RunConfiguration(
            providerID: providerID,
            apiKey: apiKey,
            transcriptionOptions: TranscriptionOptions(
                languageCode: languageCode.isEmpty ? nil : languageCode,
                diarize: diarize,
                keyterms: keyterms
            ),
            segmenterOptions: SegmenterOptions(
                maxCharsPerLine: maxCharsPerLine,
                maxCueDuration: maxCueDuration
            ),
            srtOptions: SRTWriter.Options(colorSpeakers: diarize && colorSpeakers),
            maxConcurrent: max(1, min(4, maxConcurrent)),
            saveRawTranscript: saveRawTranscript
        )
    }
}

/// Immutable snapshot of everything a transcription run needs, taken when Start is pressed.
nonisolated struct RunConfiguration: Sendable {
    var providerID: String
    var apiKey: String?
    var transcriptionOptions: TranscriptionOptions
    var segmenterOptions: SegmenterOptions
    var srtOptions: SRTWriter.Options
    var maxConcurrent: Int
    var saveRawTranscript: Bool
}
