import Foundation

/// Builds a multipart/form-data body on disk so multi-gigabyte uploads never sit in memory.
public final class MultipartFormFile {
    public let boundary: String
    public let url: URL
    private let handle: FileHandle
    private var finished = false

    public init(directory: URL = FileManager.default.temporaryDirectory) throws {
        boundary = "Boundary-" + UUID().uuidString
        url = directory.appending(path: "upload-\(UUID().uuidString).multipart")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        handle = try FileHandle(forWritingTo: url)
    }

    deinit {
        try? handle.close()
    }

    public func addField(_ name: String, value: String) throws {
        try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
    }

    public func addJSONField(_ name: String, json: Data) throws {
        try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\nContent-Type: application/json\r\n\r\n")
        try handle.write(contentsOf: json)
        try write("\r\n")
    }

    public func addFile(_ name: String, fileURL: URL, filename: String, contentType: String) throws {
        try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(contentType)\r\n\r\n")
        let reader = try FileHandle(forReadingFrom: fileURL)
        defer { try? reader.close() }
        while let chunk = try reader.read(upToCount: 1 << 20), !chunk.isEmpty {
            try handle.write(contentsOf: chunk)
        }
        try write("\r\n")
    }

    public func finish() throws {
        guard !finished else { return }
        try write("--\(boundary)--\r\n")
        try handle.close()
        finished = true
    }

    public func remove() {
        try? handle.close()
        try? FileManager.default.removeItem(at: url)
    }

    private func write(_ string: String) throws {
        try handle.write(contentsOf: Data(string.utf8))
    }
}
