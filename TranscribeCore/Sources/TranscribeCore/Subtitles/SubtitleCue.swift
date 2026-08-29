import Foundation

public struct SubtitleCue: Sendable, Equatable {
    public var start: TimeInterval
    public var end: TimeInterval
    public var lines: [String]
    public var speaker: String?

    public init(start: TimeInterval, end: TimeInterval, lines: [String], speaker: String? = nil) {
        self.start = start
        self.end = end
        self.lines = lines
        self.speaker = speaker
    }

    public var text: String { lines.joined(separator: "\n") }
    public var duration: TimeInterval { end - start }
}
