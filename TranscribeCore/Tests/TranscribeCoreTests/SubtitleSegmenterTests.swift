import Foundation
import Testing
@testable import TranscribeCore

private func w(_ text: String, _ start: Double, _ end: Double, speaker: String? = nil) -> TranscriptWord {
    TranscriptWord(text: text, start: start, end: end, speaker: speaker)
}

/// Continuous speech: each word lasts `wordDuration`, separated by `gap`.
private func speech(_ texts: [String], from startAt: Double = 0, wordDuration: Double = 0.3, gap: Double = 0.05) -> [TranscriptWord] {
    var t = startAt
    return texts.map { text in
        defer { t += wordDuration + gap }
        return w(text, t, t + wordDuration)
    }
}

@Suite struct SubtitleSegmenterTests {
    let options = SegmenterOptions()

    @Test func emptyInputYieldsNoCues() {
        #expect(SubtitleSegmenter.segment([]).isEmpty)
        #expect(SubtitleSegmenter.segment([TranscriptWord(text: " ", kind: .spacing, start: 0, end: 0)]).isEmpty)
    }

    @Test func singleWordIsExtendedToMinimumDuration() {
        let cues = SubtitleSegmenter.segment([w("سلام", 1.0, 1.3)])
        #expect(cues.count == 1)
        #expect(cues[0].lines == ["سلام"])
        #expect(cues[0].start == 1.0)
        #expect(cues[0].end == 2.0)
    }

    @Test func longRunRespectsLineAndCueLimits() {
        let words = speech((1...60).map { "word\($0)" })
        let cues = SubtitleSegmenter.segment(words, options: options)
        #expect(cues.count > 1)
        for cue in cues {
            #expect(cue.lines.count <= options.maxLines)
            for line in cue.lines { #expect(TextMeasure.visibleCount(line) <= options.maxCharsPerLine) }
            #expect(cue.duration <= options.maxCueDuration + 0.001)
        }
        let allText = cues.flatMap(\.lines).joined(separator: " ")
        #expect(allText == words.map(\.text).joined(separator: " "))
    }

    @Test func balancedTwoLineWrap() {
        let words = speech((1...11).map { "abcde\($0 % 10)" })  // 11 × 6 chars → needs two lines
        let cues = SubtitleSegmenter.segment(words)
        #expect(cues.count == 1)
        #expect(cues[0].lines.count == 2)
        let lengths = cues[0].lines.map { TextMeasure.visibleCount($0) }
        #expect(abs(lengths[0] - lengths[1]) <= 7)
    }

    @Test func silenceGapSplitsCue() {
        let first = speech(["one", "two", "three"])
        let second = speech(["four", "five"], from: first.last!.end + 1.0)
        let cues = SubtitleSegmenter.segment(first + second)
        #expect(cues.count == 2)
        #expect(cues[0].lines == ["one two three"])
        #expect(cues[1].lines == ["four five"])
        #expect(cues[1].start == second[0].start)
    }

    @Test func persianSentenceEndersSplit() {
        let words = speech(["حال", "شما", "چطور", "است؟", "من", "خوبم", "و", "شما", "خوبید.", "بله"])
        let cues = SubtitleSegmenter.segment(words)
        #expect(cues.count == 3)
        #expect(cues[0].text == "حال شما چطور است؟")
        #expect(cues[1].text == "من خوبم و شما خوبید.")
        #expect(cues[2].text == "بله")
    }

    @Test func tinyFragmentAfterSentenceStaysAttached() {
        // "بله." is under 10 chars and followed immediately by more words: don't make a one-word cue.
        let words = speech(["بله.", "من", "می‌آیم"], gap: 0.05)
        let cues = SubtitleSegmenter.segment(words)
        #expect(cues.count == 1)
    }

    @Test func slowSpeechNeverExceedsMaxDuration() {
        let words = speech((1...30).map { "w\($0)" }, wordDuration: 0.9, gap: 0.1)
        let cues = SubtitleSegmenter.segment(words)
        for cue in cues { #expect(cue.duration <= options.maxCueDuration + 0.001) }
    }

    @Test func overflowBacksUpToClauseBreak() {
        // 15 five-letter words overflow two 42-char lines; word 10 ends with "،".
        var texts = (1...15).map { _ in "abcde" }
        texts[9] = "abcd،"
        let cues = SubtitleSegmenter.segment(speech(texts, wordDuration: 0.3, gap: 0.05))
        #expect(cues.count == 2)
        #expect(cues[0].lines.joined(separator: " ").split(separator: " ").count == 10)
        #expect(cues[0].lines.last!.hasSuffix("،"))
    }

    @Test func zeroWidthCharactersDoNotCount() {
        #expect(TextMeasure.visibleCount("می‌خواهم") == 7)
        #expect(TextMeasure.visibleCount("abc") == 3)
        #expect(TextMeasure.visibleCount("\u{200F}سلام\u{200C}") == 4)
        #expect(TextMeasure.visibleCount("بَ") == 1)
    }

    @Test func speakerChangeSplitsWhenEnabled() {
        var words = speech(["hello", "there", "my", "friend"])
        words[2].speaker = "B"; words[3].speaker = "B"
        words[0].speaker = "A"; words[1].speaker = "A"
        #expect(SubtitleSegmenter.segment(words).count == 2)
        let joined = SubtitleSegmenter.segment(words, options: SegmenterOptions(splitOnSpeakerChange: false))
        #expect(joined.count == 1)
    }

    @Test func cuesCarryTheirSpeaker() {
        var words = speech(["hello", "there", "my", "friend"])
        words[0].speaker = "A"; words[1].speaker = "A"; words[2].speaker = "B"; words[3].speaker = "B"
        let cues = SubtitleSegmenter.segment(words)
        #expect(cues.map(\.text) == ["hello there", "my friend"])
        #expect(cues.map(\.speaker) == ["A", "B"])
    }

    @Test func cuesNeverOverlapAfterExtension() {
        // Many short sentences close together: min-duration extension must be clamped.
        let words = speech((1...20).map { "ok\($0)." }, wordDuration: 0.2, gap: 0.1)
        let cues = SubtitleSegmenter.segment(words)
        for (a, b) in zip(cues, cues.dropFirst()) {
            #expect(a.end <= b.start - options.minGapBetweenCues + 0.0001)
            #expect(a.end > a.start)
        }
    }

    @Test func audioEventsAreDroppedByDefault() {
        let words = [w("hi", 0, 0.3), TranscriptWord(text: "laughter", kind: .audioEvent, start: 0.4, end: 0.85), w("there", 0.9, 1.2)]
        #expect(SubtitleSegmenter.segment(words).map(\.text) == ["hi there"])
        let with = SubtitleSegmenter.segment(words, options: SegmenterOptions(includeAudioEvents: true))
        #expect(with.map(\.text) == ["hi [laughter] there"])
    }

    @Test func deterministic() {
        let words = speech((1...80).map { "کلمه\($0)" }, wordDuration: 0.35, gap: 0.08)
        #expect(SubtitleSegmenter.segment(words) == SubtitleSegmenter.segment(words))
    }
}
