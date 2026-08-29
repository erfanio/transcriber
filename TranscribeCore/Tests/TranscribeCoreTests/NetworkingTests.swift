import Foundation
import Testing
@testable import TranscribeCore

@Suite struct MultipartFormFileTests {
    @Test func writesWellFormedBody() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "multipart-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = Data((0..<(3 * 1024 * 1024 + 17)).map { UInt8($0 % 251) })
        let audio = directory.appending(path: "audio.m4a")
        try payload.write(to: audio)

        let form = try MultipartFormFile(directory: directory)
        try form.addField("model_id", value: "scribe_v2")
        try form.addField("keyterms", value: "علی")
        try form.addField("keyterms", value: "Tehran")
        try form.addJSONField("additional_formats", json: Data(#"[{"format":"srt"}]"#.utf8))
        try form.addFile("file", fileURL: audio, filename: "audio.m4a", contentType: "audio/mp4")
        try form.finish()

        let body = try Data(contentsOf: form.url)
        let boundary = form.boundary
        let fileHeaderEnd = body.range(of: Data("Content-Type: audio/mp4\r\n\r\n".utf8))!.upperBound
        let text = String(decoding: body[..<fileHeaderEnd], as: UTF8.self)
        #expect(text.hasPrefix("--\(boundary)\r\nContent-Disposition: form-data; name=\"model_id\"\r\n\r\nscribe_v2\r\n"))
        #expect(text.contains("Content-Disposition: form-data; name=\"keyterms\"\r\n\r\nعلی\r\n"))
        #expect(text.contains("name=\"additional_formats\"\r\nContent-Type: application/json\r\n\r\n[{\"format\":\"srt\"}]\r\n"))
        #expect(text.contains("name=\"file\"; filename=\"audio.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n"))

        let closing = Data("\r\n--\(boundary)--\r\n".utf8)
        #expect(body.suffix(closing.count) == closing)
        #expect(body[fileHeaderEnd..<(fileHeaderEnd + payload.count)] == payload)
        #expect(body.count == fileHeaderEnd + payload.count + closing.count)

        form.remove()
        #expect(!FileManager.default.fileExists(atPath: form.url.path))
    }
}

@Suite struct RetryPolicyTests {
    let policy = RetryPolicy(maxAttempts: 4, baseDelay: 2, maxDelay: 60, jitter: 0)

    @Test func schedule() {
        let error = TranscriptionError.serverError(status: 503, message: "busy")
        #expect(policy.delay(afterAttempt: 1, error: error) == 2)
        #expect(policy.delay(afterAttempt: 2, error: error) == 4)
        #expect(policy.delay(afterAttempt: 3, error: error) == 8)
        #expect(policy.delay(afterAttempt: 4, error: error) == nil)
    }

    @Test func honoursRetryAfterAndRateLimitFloor() {
        #expect(policy.delay(afterAttempt: 1, error: .rateLimited(retryAfter: 17)) == 17)
        #expect(policy.delay(afterAttempt: 1, error: .rateLimited(retryAfter: nil)) == 5)
        #expect(policy.delay(afterAttempt: 1, error: .network(code: .timedOut, message: "")) == 2)
    }

    @Test func neverRetriesClientErrors() {
        #expect(policy.delay(afterAttempt: 1, error: .invalidAPIKey) == nil)
        #expect(policy.delay(afterAttempt: 1, error: .badRequest("x")) == nil)
        #expect(policy.delay(afterAttempt: 1, error: .fileTooLarge) == nil)
        #expect(policy.delay(afterAttempt: 1, error: .network(code: .badURL, message: "")) == nil)
    }
}

@Suite struct HTTPErrorMapperTests {
    @Test func mapsElevenLabsDetailObject() {
        let body = Data(#"{"detail":{"status":"invalid_api_key","message":"Invalid API key"}}"#.utf8)
        #expect(HTTPErrorMapper.map(status: 401, data: body) == .invalidAPIKey)
        #expect(HTTPErrorMapper.map(status: 429, data: body, retryAfterHeader: "12") == .rateLimited(retryAfter: 12))
        #expect(HTTPErrorMapper.map(status: 503, data: body) == .serverError(status: 503, message: "Invalid API key"))
        let tooLarge = Data(#"{"detail":{"status":"request_too_large","message":"File exceeds limit"}}"#.utf8)
        #expect(HTTPErrorMapper.map(status: 400, data: tooLarge) == .fileTooLarge)
        #expect(HTTPErrorMapper.map(status: 413, data: Data()) == .fileTooLarge)
        let noPermission = Data(#"{"detail":{"status":"missing_permissions","message":"The API key you used is missing the permission user_read"}}"#.utf8)
        #expect(HTTPErrorMapper.map(status: 401, data: noPermission) == .missingPermissions("The API key you used is missing the permission user_read"))
        #expect(HTTPErrorMapper.map(status: 401, data: noPermission).isRetryable == false)
    }

    @Test func mapsDetailStringAndGarbage() {
        #expect(HTTPErrorMapper.map(status: 422, data: Data(#"{"detail":"language_code is invalid"}"#.utf8)) == .badRequest("language_code is invalid"))
        #expect(HTTPErrorMapper.map(status: 418, data: Data("teapot".utf8)) == .unexpectedStatus(418, "teapot"))
        #expect(HTTPErrorMapper.map(status: 402, data: Data()) == .insufficientCredits)
    }
}
