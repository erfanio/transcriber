import Foundation

public enum SRTWriter {
    public static func render(_ cues: [SubtitleCue], includeBOM: Bool = false) -> String {
        var output = includeBOM ? "\u{FEFF}" : ""
        for (index, cue) in cues.enumerated() {
            output += "\(index + 1)\n"
            output += "\(timestamp(cue.start)) --> \(timestamp(cue.end))\n"
            output += cue.lines.joined(separator: "\n")
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
