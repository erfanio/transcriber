import Foundation

/// Offline stand-in that returns canned Persian words, for exercising the app without an API key.
public struct MockTranscriptionProvider: TranscriptionProvider {
    public static let providerID = "mock"

    public let id = MockTranscriptionProvider.providerID
    public let displayName = "Mock (offline test)"
    public var simulatedDelay: TimeInterval
    public var failEveryNth: Int?

    public init(simulatedDelay: TimeInterval = 2.0, failEveryNth: Int? = nil) {
        self.simulatedDelay = simulatedDelay
        self.failEveryNth = failEveryNth
    }

    public func validateCredentials() async throws -> String {
        try await Task.sleep(for: .milliseconds(300))
        return "Mock provider — no key needed"
    }

    public func transcribe(
        audioFileURL: URL,
        options: TranscriptionOptions,
        progress: @Sendable @escaping (TranscriptionProgress) -> Void
    ) async throws -> Transcript {
        let steps = 10
        for step in 1...steps {
            try await Task.sleep(for: .seconds(simulatedDelay / 2 / Double(steps)))
            progress(.uploading(fraction: Double(step) / Double(steps)))
        }
        progress(.processing)
        try await Task.sleep(for: .seconds(simulatedDelay / 2))

        if let n = failEveryNth, n > 0, abs(audioFileURL.path.hashValue) % n == 0 {
            throw TranscriptionError.serverError(status: 500, message: "Simulated failure")
        }

        let words = Self.cannedWords()
        return Transcript(
            providerID: id,
            languageCode: options.languageCode ?? "fas",
            text: words.map(\.text).joined(separator: " "),
            words: words,
            audioDuration: words.last?.end,
            providerResponse: .object(["mock": .bool(true)])
        )
    }

    static func cannedWords() -> [TranscriptWord] {
        let script = """
        سلام، این یک متن آزمایشی است. امروز هوا خیلی خوب است؟ ما داریم فیلم می‌سازیم، \
        و زیرنویس‌ها به‌صورت خودکار ساخته می‌شوند. این جمله برای بررسی شکستن خطوط طولانی \
        نوشته شده است تا ببینیم چگونه تقسیم می‌شود. خیلی ممنون از توجه شما!
        """
        var words: [TranscriptWord] = []
        var t: TimeInterval = 0.4
        for token in script.split(separator: " ") {
            let text = String(token)
            let duration = 0.25 + Double(text.count) * 0.06
            words.append(TranscriptWord(text: text, start: t, end: t + duration))
            t += duration + 0.08
            if let last = text.last, ".!؟?".contains(last) { t += 0.9 }
        }
        return words
    }
}
