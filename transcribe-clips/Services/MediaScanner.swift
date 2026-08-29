import Foundation
import UniformTypeIdentifiers

nonisolated struct ScannedClip: Sendable {
    let url: URL
    let relativeName: String
    let hasExistingSRT: Bool
    /// A `.transcript.json` from an earlier run exists, so subtitles can be rebuilt without uploading.
    let hasSavedTranscript: Bool
    /// Another clip in the same folder shares this base name, so they would fight over one `.srt`.
    let nameCollision: Bool
}

nonisolated enum MediaScanner {
    @concurrent
    static func scan(folder: URL) async -> [ScannedClip] {
        var found = mediaFiles(in: folder)
        let folderPath = folder.standardizedFileURL.path(percentEncoded: false)
        found.sort { $0.path(percentEncoded: false).localizedStandardCompare($1.path(percentEncoded: false)) == .orderedAscending }

        var seenBaseNames = Set<String>()
        return found.map { url in
            let base = url.deletingPathExtension().path(percentEncoded: false)
            let collision = !seenBaseNames.insert(base).inserted
            var relative = url.standardizedFileURL.path(percentEncoded: false)
            if relative.hasPrefix(folderPath) {
                relative = String(relative.dropFirst(folderPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
            let stem = url.deletingPathExtension()
            return ScannedClip(
                url: url,
                relativeName: relative.isEmpty ? url.lastPathComponent : relative,
                hasExistingSRT: FileManager.default.fileExists(atPath: stem.appendingPathExtension("srt").path(percentEncoded: false)),
                hasSavedTranscript: FileManager.default.fileExists(atPath: stem.appendingPathExtension("transcript.json").path(percentEncoded: false)),
                nameCollision: collision
            )
        }
    }

    private static func mediaFiles(in folder: URL) -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentTypeKey, .isPackageKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [URL] = []
        for case let url as URL in enumerator {
            if Task.isCancelled { return [] }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  values.isPackage != true,
                  let type = values.contentType,
                  type.conforms(to: .audiovisualContent)
            else { continue }
            found.append(url)
        }
        return found
    }
}
