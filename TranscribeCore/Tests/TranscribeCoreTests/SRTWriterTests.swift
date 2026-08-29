import Foundation
import Testing
@testable import TranscribeCore

@Suite struct SRTWriterTests {
    @Test func timestamps() {
        #expect(SRTWriter.timestamp(0) == "00:00:00,000")
        #expect(SRTWriter.timestamp(3661.5) == "01:01:01,500")
        #expect(SRTWriter.timestamp(0.0006) == "00:00:00,001")
        #expect(SRTWriter.timestamp(59.9996) == "00:01:00,000")
        #expect(SRTWriter.timestamp(-3) == "00:00:00,000")
        #expect(SRTWriter.timestamp(36_000.25) == "10:00:00,250")
    }

    @Test func rendersExactSRT() {
        let cues = [
            SubtitleCue(start: 1.0, end: 3.5, lines: ["سلام، این یک", "متن آزمایشی است."]),
            SubtitleCue(start: 4.25, end: 6.0, lines: ["Line two"]),
        ]
        let expected = """
        1
        00:00:01,000 --> 00:00:03,500
        سلام، این یک
        متن آزمایشی است.

        2
        00:00:04,250 --> 00:00:06,000
        Line two


        """
        #expect(SRTWriter.render(cues) == expected)
        #expect(SRTWriter.render(cues, includeBOM: true).hasPrefix("\u{FEFF}1\n"))
        #expect(SRTWriter.render([]) == "")
    }

    @Test func coloursSpeakersInOrderOfAppearance() {
        let cues = [
            SubtitleCue(start: 0, end: 1, lines: ["سلام", "خوبی؟"], speaker: "speaker_1"),
            SubtitleCue(start: 1, end: 2, lines: ["بله"], speaker: "speaker_0"),
            SubtitleCue(start: 2, end: 3, lines: ["خوبم"], speaker: "speaker_1"),
            SubtitleCue(start: 3, end: 4, lines: ["(music)"]),
        ]
        let srt = SRTWriter.render(cues, options: .init(colorSpeakers: true, speakerPalette: ["#FFFFFF", "#FFD400"]))
        #expect(srt.contains("<font color=\"#FFFFFF\">سلام</font>\n<font color=\"#FFFFFF\">خوبی؟</font>"))
        #expect(srt.contains("<font color=\"#FFD400\">بله</font>"))
        #expect(srt.contains("<font color=\"#FFFFFF\">خوبم</font>"))
        #expect(srt.contains("\n(music)\n"))
        #expect(!SRTWriter.render(cues).contains("<font"))
    }

    @Test func mockProviderProducesUsableSubtitles() async throws {
        let provider = MockTranscriptionProvider(simulatedDelay: 0.01)
        let transcript = try await provider.transcribe(audioFileURL: URL(fileURLWithPath: "/tmp/x.m4a"), options: .init()) { _ in }
        let cues = SubtitleSegmenter.segment(transcript.words)
        #expect(cues.count >= 4)
        #expect(SRTWriter.render(cues).contains("-->"))
    }
}
