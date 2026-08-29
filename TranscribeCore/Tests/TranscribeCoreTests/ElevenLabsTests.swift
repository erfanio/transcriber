import Foundation
import Synchronization
import Testing
@testable import TranscribeCore

private let fixture = """
{
  "language_code": "fas",
  "language_probability": 0.98,
  "text": "سلام دنیا. خوبی؟",
  "transcription_id": "abc123",
  "audio_duration_secs": 3.5,
  "words": [
    {"text": "سلام", "type": "word", "start": 0.1, "end": 0.5, "speaker_id": "speaker_0", "logprob": -0.1},
    {"text": " ", "type": "spacing", "start": 0.5, "end": 0.6},
    {"text": "دنیا", "type": "word", "start": 0.6, "end": 1.0, "speaker_id": "speaker_0"},
    {"text": ".", "type": "word", "start": 1.0, "end": 1.05, "speaker_id": "speaker_0"},
    {"text": "(laughter)", "type": "audio_event", "start": 1.2, "end": 2.0},
    {"text": "خوبی؟", "type": "word", "start": 2.1, "end": 2.6, "speaker_id": "speaker_1"}
  ]
}
"""

@Suite struct ElevenLabsDecodingTests {
    @Test func mapsResponseToTranscript() throws {
        let transcript = try ElevenLabsDTO.transcript(from: Data(fixture.utf8), providerID: "elevenlabs")
        #expect(transcript.languageCode == "fas")
        #expect(transcript.audioDuration == 3.5)
        #expect(transcript.text == "سلام دنیا. خوبی؟")
        #expect(transcript.words.map(\.text) == ["سلام", "دنیا.", "(laughter)", "خوبی؟"])
        #expect(transcript.words.map(\.kind) == [.word, .word, .audioEvent, .word])
        #expect(transcript.words[1].end == 1.05)
        #expect(transcript.words[3].speaker == "speaker_1")
        if case .object(let object)? = transcript.providerResponse {
            #expect(object["transcription_id"] == .string("abc123"))
        } else {
            Issue.record("raw provider response not preserved")
        }
    }

    @Test func rejectsMalformedJSON() {
        #expect(throws: TranscriptionError.self) {
            try ElevenLabsDTO.transcript(from: Data("{".utf8), providerID: "x")
        }
    }
}

// MARK: - Stubbed HTTP transport

final class StubURLProtocol: URLProtocol {
    struct Response {
        var status: Int
        var body: Data
        var headers: [String: String] = [:]
    }

    struct State {
        var responses: [Response] = []
        var requests: [URLRequest] = []
    }

    static let state = Mutex(State())

    static func reset(responses: [Response]) {
        state.withLock { $0 = State(responses: responses) }
    }

    static var requests: [URLRequest] { state.withLock { $0.requests } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let response = Self.state.withLock { state -> Response in
            state.requests.append(request)
            return state.responses.isEmpty ? Response(status: 500, body: Data()) : state.responses.removeFirst()
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: response.headers)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

@Suite(.serialized) struct ElevenLabsProviderTests {
    private func makeProvider() -> ElevenLabsScribeProvider {
        ElevenLabsScribeProvider(
            apiKey: "sk-test",
            session: StubURLProtocol.makeSession(),
            retryPolicy: RetryPolicy(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.02, jitter: 0)
        )
    }

    private func tempAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "stub-\(UUID().uuidString).m4a")
        try Data(repeating: 7, count: 1024).write(to: url)
        return url
    }

    @Test func retriesRateLimitThenSucceeds() async throws {
        StubURLProtocol.reset(responses: [
            .init(status: 429, body: Data(#"{"detail":{"status":"rate_limit_exceeded","message":"slow down"}}"#.utf8), headers: ["Retry-After": "0"]),
            .init(status: 200, body: Data(fixture.utf8)),
        ])
        let audio = try tempAudio()
        defer { try? FileManager.default.removeItem(at: audio) }

        let updates = Mutex<[TranscriptionProgress]>([])
        let transcript = try await makeProvider().transcribe(
            audioFileURL: audio,
            options: TranscriptionOptions(languageCode: "fas", keyterms: ["علی", "", "x"])
        ) { update in updates.withLock { $0.append(update) } }

        #expect(transcript.words.count == 4)
        let requests = StubURLProtocol.requests
        #expect(requests.count == 2)
        #expect(requests[0].url?.path == "/v1/speech-to-text")
        #expect(requests[0].httpMethod == "POST")
        #expect(requests[0].value(forHTTPHeaderField: "xi-api-key") == "sk-test")
        #expect(requests[0].value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=Boundary-") == true)
        #expect(updates.withLock { $0 }.contains { if case .waitingToRetry = $0 { true } else { false } })
    }

    @Test func invalidKeyIsNotRetried() async throws {
        StubURLProtocol.reset(responses: [
            .init(status: 401, body: Data(#"{"detail":{"status":"invalid_api_key","message":"nope"}}"#.utf8)),
        ])
        let audio = try tempAudio()
        defer { try? FileManager.default.removeItem(at: audio) }

        await #expect(throws: TranscriptionError.invalidAPIKey) {
            try await makeProvider().transcribe(audioFileURL: audio, options: TranscriptionOptions()) { _ in }
        }
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test func validateCredentialsSummarisesAccount() async throws {
        StubURLProtocol.reset(responses: [
            .init(status: 200, body: Data(#"{"subscription":{"tier":"creator","character_count":1200,"character_limit":100000,"status":"active"}}"#.utf8)),
        ])
        let summary = try await makeProvider().validateCredentials()
        #expect(summary.contains("Creator plan"))
        #expect(StubURLProtocol.requests.first?.url?.path == "/v1/user")

        StubURLProtocol.reset(responses: [.init(status: 401, body: Data())])
        await #expect(throws: TranscriptionError.invalidAPIKey) {
            try await makeProvider().validateCredentials()
        }

        // A key with only the Speech to Text permission is still a valid key.
        StubURLProtocol.reset(responses: [
            .init(status: 401, body: Data(#"{"detail":{"status":"missing_permissions","message":"missing user_read"}}"#.utf8)),
        ])
        let restricted = try await makeProvider().validateCredentials()
        #expect(restricted.hasPrefix("Key is valid"))
        #expect(restricted.contains("User"))
    }

    @Test func multipartTempFileIsRemovedAfterwards() async throws {
        StubURLProtocol.reset(responses: [.init(status: 200, body: Data(fixture.utf8))])
        let audio = try tempAudio()
        defer { try? FileManager.default.removeItem(at: audio) }
        _ = try await makeProvider().transcribe(audioFileURL: audio, options: TranscriptionOptions()) { _ in }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)
            .filter { $0.hasPrefix("upload-") && $0.hasSuffix(".multipart") }
        #expect(leftovers.isEmpty)
    }
}
