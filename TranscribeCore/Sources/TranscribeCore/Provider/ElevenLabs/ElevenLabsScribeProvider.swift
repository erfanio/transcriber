import Foundation

/// ElevenLabs Speech-to-Text (Scribe v2) via `POST /v1/speech-to-text`.
public struct ElevenLabsScribeProvider: TranscriptionProvider {
    public static let providerID = "elevenlabs-scribe-v2"
    public static let defaultBaseURL = URL(string: "https://api.elevenlabs.io")!

    public let id = ElevenLabsScribeProvider.providerID
    public let displayName = "ElevenLabs Scribe v2"

    let apiKey: String
    let baseURL: URL
    let session: URLSession
    let retryPolicy: RetryPolicy
    let modelID: String

    public init(
        apiKey: String,
        baseURL: URL = ElevenLabsScribeProvider.defaultBaseURL,
        session: URLSession? = nil,
        retryPolicy: RetryPolicy = RetryPolicy(),
        modelID: String = "scribe_v2"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session ?? Self.makeSession()
        self.retryPolicy = retryPolicy
        self.modelID = modelID
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        // Idle timeout: the server may stay silent for minutes while it transcribes a long file.
        configuration.timeoutIntervalForRequest = 30 * 60
        configuration.timeoutIntervalForResource = 6 * 60 * 60
        configuration.waitsForConnectivity = true
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    // MARK: - Credentials

    /// Uses `GET /v1/user`, which needs the optional "User" permission. A key that only has
    /// "Speech to Text" answers `missing_permissions`, which still proves the key itself is valid.
    public func validateCredentials() async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: "v1/user"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        apply(headers: &request)

        let (data, response) = try await perform { try await session.data(for: request) }
        guard response.statusCode == 200 else {
            let error = HTTPErrorMapper.map(status: response.statusCode, data: data, retryAfterHeader: response.value(forHTTPHeaderField: "Retry-After"))
            if case .missingPermissions = error {
                return "Key is valid · usage not visible (add the “User” permission to the key to show it)"
            }
            throw error
        }
        let user = try? JSONDecoder().decode(ElevenLabsDTO.UserResponse.self, from: data)
        var parts: [String] = ["Key is valid"]
        if let subscription = user?.subscription {
            if let tier = subscription.tier, !tier.isEmpty { parts.append(tier.capitalized + " plan") }
            if let used = subscription.characterCount, let limit = subscription.characterLimit, limit > 0 {
                parts.append("\(used.formatted()) / \(limit.formatted()) credits used")
            }
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Transcription

    public func transcribe(
        audioFileURL: URL,
        options: TranscriptionOptions,
        progress: @Sendable @escaping (TranscriptionProgress) -> Void
    ) async throws -> Transcript {
        let form = try buildForm(audioFileURL: audioFileURL, options: options)
        defer { form.remove() }

        var attempt = 0
        while true {
            attempt += 1
            try Task.checkCancellation()
            do {
                return try await upload(form, progress: progress)
            } catch let error as TranscriptionError {
                guard let delay = retryPolicy.delay(afterAttempt: attempt, error: error) else { throw error }
                progress(.waitingToRetry(seconds: delay))
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }

    func buildForm(audioFileURL: URL, options: TranscriptionOptions) throws -> MultipartFormFile {
        let form = try MultipartFormFile()
        do {
            try form.addField("model_id", value: modelID)
            if let language = options.languageCode, !language.isEmpty {
                try form.addField("language_code", value: language)
            }
            try form.addField("timestamps_granularity", value: "word")
            try form.addField("diarize", value: options.diarize ? "true" : "false")
            try form.addField("tag_audio_events", value: options.tagAudioEvents ? "true" : "false")
            if options.diarize, let speakers = options.numSpeakers, speakers > 0 {
                try form.addField("num_speakers", value: String(min(32, speakers)))
            }
            for term in Self.sanitizedKeyterms(options.keyterms) {
                try form.addField("keyterms", value: term)
            }
            try form.addFile(
                "file",
                fileURL: audioFileURL,
                filename: "audio." + (audioFileURL.pathExtension.isEmpty ? "m4a" : audioFileURL.pathExtension),
                contentType: Self.contentType(for: audioFileURL)
            )
            try form.finish()
        } catch {
            form.remove()
            throw error
        }
        return form
    }

    static func sanitizedKeyterms(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        return terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count < 50 && seen.insert($0).inserted }
            .prefix(1000)
            .map { $0 }
    }

    static func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a", "mp4": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aac": return "audio/aac"
        case "flac": return "audio/flac"
        case "ogg", "opus": return "audio/ogg"
        default: return "application/octet-stream"
        }
    }

    private func upload(_ form: MultipartFormFile, progress: @Sendable @escaping (TranscriptionProgress) -> Void) async throws -> Transcript {
        var request = URLRequest(url: baseURL.appending(path: "v1/speech-to-text"))
        request.httpMethod = "POST"
        request.timeoutInterval = session.configuration.timeoutIntervalForRequest
        request.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        apply(headers: &request)

        let delegate = UploadProgressDelegate { fraction in
            progress(fraction >= 1 ? .processing : .uploading(fraction: fraction))
        }
        let (data, response) = try await perform {
            try await session.upload(for: request, fromFile: form.url, delegate: delegate)
        }
        guard response.statusCode == 200 else {
            throw HTTPErrorMapper.map(status: response.statusCode, data: data, retryAfterHeader: response.value(forHTTPHeaderField: "Retry-After"))
        }
        return try ElevenLabsDTO.transcript(from: data, providerID: id)
    }

    private func apply(headers request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func perform(_ operation: () async throws -> (Data, URLResponse)) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await operation()
            guard let http = response as? HTTPURLResponse else {
                throw TranscriptionError.unexpectedStatus(0, "Not an HTTP response")
            }
            return (data, http)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw TranscriptionError.network(code: error.code, message: error.localizedDescription)
        }
    }
}
