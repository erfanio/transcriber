import Foundation

/// Turns timed words into subtitle cues that respect line length, duration and natural pauses.
/// Pure and deterministic, so the same transcript always yields the same cues.
public enum SubtitleSegmenter {
    struct Token {
        var text: String
        var start: TimeInterval
        var end: TimeInterval
        var speaker: String?
        var length: Int
        var endsSentence: Bool
        var endsClause: Bool
    }

    public static func segment(_ words: [TranscriptWord], options: SegmenterOptions = SegmenterOptions()) -> [SubtitleCue] {
        let tokens = tokenize(words, options: options)
        guard !tokens.isEmpty else { return [] }
        let groups = mergeFragments(group(tokens, options: options), options: options)
        var cues = groups.map { makeCue($0, options: options) }
        fixTiming(&cues, options: options)
        return cues
    }

    // MARK: - Tokenizing

    private static let trailingClosers: Set<Character> = ["\"", "»", ")", "]", "'", "”", "’"]

    static func tokenize(_ words: [TranscriptWord], options: SegmenterOptions) -> [Token] {
        var tokens: [Token] = []
        for word in words {
            let text: String
            switch word.kind {
            case .word:
                text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            case .audioEvent:
                guard options.includeAudioEvents else { continue }
                let inner = word.text.trimmingCharacters(in: CharacterSet(charactersIn: "()[] \n"))
                text = "[\(inner)]"
            case .spacing:
                continue
            }
            guard !text.isEmpty else { continue }
            let last = text.reversed().first { !trailingClosers.contains($0) }
            tokens.append(Token(
                text: text,
                start: word.start,
                end: max(word.end, word.start),
                speaker: word.speaker,
                length: TextMeasure.visibleCount(text),
                endsSentence: last.map { options.sentenceEnders.contains($0) } ?? false,
                endsClause: last.map { options.clauseBreaks.contains($0) } ?? false
            ))
        }
        return tokens
    }

    // MARK: - Grouping

    static func group(_ tokens: [Token], options: SegmenterOptions) -> [[Token]] {
        var groups: [[Token]] = []
        var current: [Token] = [tokens[0]]
        var index = 1
        while index < tokens.count {
            let token = tokens[index]
            let previous = current[current.count - 1]
            var mustBreak = false

            if token.start - previous.end >= options.minGapToSplit {
                mustBreak = true
            } else if token.end - current[0].start > options.maxCueDuration {
                mustBreak = true
            } else if options.splitOnSpeakerChange, token.speaker != previous.speaker {
                mustBreak = true
            } else if previous.endsSentence {
                let tinyCue = textLength(current) < 10 && token.start - previous.end < 0.3
                mustBreak = !tinyCue
            }

            if !mustBreak, !fits(current + [token], options: options) {
                // Prefer ending the cue on a clause break rather than wherever the text overflowed.
                if let cut = current.lastIndex(where: { $0.endsClause || $0.endsSentence }),
                   cut + 1 >= max(1, current.count / 3),
                   cut < current.count - 1 {
                    groups.append(Array(current[...cut]))
                    current = Array(current[(cut + 1)...])
                    continue
                }
                mustBreak = true
            }

            if mustBreak {
                groups.append(current)
                current = [token]
            } else {
                current.append(token)
            }
            index += 1
        }
        groups.append(current)
        return groups
    }

    static func mergeFragments(_ groups: [[Token]], options: SegmenterOptions) -> [[Token]] {
        var merged: [[Token]] = []
        for group in groups {
            guard let previous = merged.last, let prevLast = previous.last, let first = group.first, let last = group.last else {
                merged.append(group)
                continue
            }
            let isTiny = (last.end - first.start) < 0.7 && textLength(group) < 10
            let sameSpeaker = !options.splitOnSpeakerChange || prevLast.speaker == first.speaker
            if isTiny,
               !prevLast.endsSentence,
               sameSpeaker,
               first.start - prevLast.end < options.minGapToSplit,
               last.end - previous[0].start <= options.maxCueDuration,
               fits(previous + group, options: options) {
                merged[merged.count - 1] = previous + group
            } else {
                merged.append(group)
            }
        }
        return merged
    }

    // MARK: - Measuring and wrapping

    static func textLength(_ tokens: [Token]) -> Int {
        guard !tokens.isEmpty else { return 0 }
        return tokens.reduce(0) { $0 + $1.length } + tokens.count - 1
    }

    static func fits(_ tokens: [Token], options: SegmenterOptions) -> Bool {
        greedyLines(tokens, options: options).count <= options.maxLines
    }

    static func greedyLines(_ tokens: [Token], options: SegmenterOptions) -> [[Token]] {
        var lines: [[Token]] = []
        var line: [Token] = []
        for token in tokens {
            if line.isEmpty || textLength(line + [token]) <= options.maxCharsPerLine {
                line.append(token)
            } else {
                lines.append(line)
                line = [token]
            }
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }

    static func wrap(_ tokens: [Token], options: SegmenterOptions) -> [String] {
        if textLength(tokens) <= options.maxCharsPerLine || tokens.count == 1 {
            return [join(tokens)]
        }
        if options.maxLines == 2 {
            var best: (score: Int, index: Int)?
            for cut in 1..<tokens.count {
                let left = Array(tokens[..<cut]), right = Array(tokens[cut...])
                let leftLength = textLength(left), rightLength = textLength(right)
                guard leftLength <= options.maxCharsPerLine, rightLength <= options.maxCharsPerLine else { continue }
                let punctuationBonus = (left[left.count - 1].endsClause || left[left.count - 1].endsSentence) ? 8 : 0
                let score = abs(leftLength - rightLength) - punctuationBonus
                if best == nil || score < best!.score { best = (score, cut) }
            }
            if let best {
                return [join(Array(tokens[..<best.index])), join(Array(tokens[best.index...]))]
            }
        }
        return greedyLines(tokens, options: options).map(join)
    }

    private static func join(_ tokens: [Token]) -> String {
        tokens.map(\.text).joined(separator: " ")
    }

    static func makeCue(_ tokens: [Token], options: SegmenterOptions) -> SubtitleCue {
        SubtitleCue(
            start: tokens[0].start,
            end: tokens[tokens.count - 1].end,
            lines: wrap(tokens, options: options),
            speaker: tokens[0].speaker
        )
    }

    // MARK: - Timing

    static func fixTiming(_ cues: inout [SubtitleCue], options: SegmenterOptions) {
        for index in cues.indices {
            let nextStart = index + 1 < cues.count ? cues[index + 1].start : nil
            if cues[index].duration < options.minCueDuration {
                var newEnd = cues[index].start + options.minCueDuration
                if let nextStart { newEnd = min(newEnd, nextStart - options.minGapBetweenCues) }
                cues[index].end = max(cues[index].end, newEnd)
            }
            if let nextStart, cues[index].end > nextStart - options.minGapBetweenCues {
                cues[index].end = nextStart - options.minGapBetweenCues
            }
            if cues[index].end <= cues[index].start {
                let fallback = cues[index].start + 0.5
                cues[index].end = nextStart.map { $0 > cues[index].start ? min(fallback, $0) : fallback } ?? fallback
            }
        }
    }
}
