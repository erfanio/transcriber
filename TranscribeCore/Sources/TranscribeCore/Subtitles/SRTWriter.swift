import Foundation

public enum SRTWriter {
    public struct Options: Sendable, Equatable {
        public var includeBOM: Bool
        /// Wrap each speaker's lines in `<font color="#RRGGBB">` tags, assigned in order of first appearance.
        public var colorSpeakers: Bool
        public var speakerPalette: [String]

        public static let defaultPalette = [
            "#FFFFFF", "#FFD400", "#4FC3F7", "#81C784", "#F48FB1", "#FFB74D", "#B39DDB", "#E57373",
        ]

        public init(includeBOM: Bool = false, colorSpeakers: Bool = false, speakerPalette: [String] = Options.defaultPalette) {
            self.includeBOM = includeBOM
            self.colorSpeakers = colorSpeakers
            self.speakerPalette = speakerPalette.isEmpty ? Options.defaultPalette : speakerPalette
        }
    }

    public static func render(_ cues: [SubtitleCue], includeBOM: Bool = false) -> String {
        render(cues, options: Options(includeBOM: includeBOM))
    }

    public static func render(_ cues: [SubtitleCue], options: Options) -> String {
        var output = options.includeBOM ? "\u{FEFF}" : ""
        var colors: [String: String] = [:]
        for (index, cue) in cues.enumerated() {
            output += "\(index + 1)\n"
            output += "\(timestamp(cue.start)) --> \(timestamp(cue.end))\n"
            var lines = cue.lines
            if options.colorSpeakers, let speaker = cue.speaker {
                let color = colors[speaker] ?? {
                    let assigned = options.speakerPalette[colors.count % options.speakerPalette.count]
                    colors[speaker] = assigned
                    return assigned
                }()
                lines = lines.map { "<font color=\"\(color)\">\($0)</font>" }
            }
            output += lines.joined(separator: "\n")
            output += "\n\n"
        }
        return output
    }

    /// `HH:MM:SS,mmm`, rounded to the nearest millisecond and clamped at zero.
    public static func timestamp(_ seconds: TimeInterval) -> String {
        let totalMilliseconds = Int((max(0, seconds) * 1000).rounded())
        let hours = totalMilliseconds / 3_600_000
        let minutes = (totalMilliseconds / 60_000) % 60
        let secs = (totalMilliseconds / 1000) % 60
        let millis = totalMilliseconds % 1000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }
}
