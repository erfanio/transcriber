import Foundation

public struct SegmenterOptions: Sendable, Equatable {
    public var maxCharsPerLine: Int
    public var maxLines: Int
    public var maxCueDuration: TimeInterval
    public var minCueDuration: TimeInterval
    /// Silence between two words that forces a new cue.
    public var minGapToSplit: TimeInterval
    public var minGapBetweenCues: TimeInterval
    public var sentenceEnders: Set<Character>
    public var clauseBreaks: Set<Character>
    public var splitOnSpeakerChange: Bool
    public var labelSpeakers: Bool
    public var includeAudioEvents: Bool

    public init(
        maxCharsPerLine: Int = 42,
        maxLines: Int = 2,
        maxCueDuration: TimeInterval = 6.0,
        minCueDuration: TimeInterval = 1.0,
        minGapToSplit: TimeInterval = 0.7,
        minGapBetweenCues: TimeInterval = 0.05,
        sentenceEnders: Set<Character> = [".", "!", "?", "؟", "…", "؛"],
        clauseBreaks: Set<Character> = [",", "،", ";", ":", "–", "—"],
        splitOnSpeakerChange: Bool = true,
        labelSpeakers: Bool = false,
        includeAudioEvents: Bool = false
    ) {
        self.maxCharsPerLine = max(10, maxCharsPerLine)
        self.maxLines = max(1, maxLines)
        self.maxCueDuration = max(1, maxCueDuration)
        self.minCueDuration = max(0, minCueDuration)
        self.minGapToSplit = max(0, minGapToSplit)
        self.minGapBetweenCues = max(0, minGapBetweenCues)
        self.sentenceEnders = sentenceEnders
        self.clauseBreaks = clauseBreaks
        self.splitOnSpeakerChange = splitOnSpeakerChange
        self.labelSpeakers = labelSpeakers
        self.includeAudioEvents = includeAudioEvents
    }
}
