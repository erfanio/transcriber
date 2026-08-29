import AVFoundation
import Foundation

/// Pulls the first audio track out of a clip into a compact `.m4a`, so uploads stay small.
nonisolated enum AudioExtractor {
    enum Failure: Error {
        case unreadable
        case noAudioTrack
        case exportFailed(String)
    }

    @concurrent
    static func extractAudio(
        from source: URL,
        to output: URL,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: source)
        let isReadable: Bool
        do {
            isReadable = try await asset.load(.isReadable)
        } catch {
            throw Failure.unreadable
        }
        guard isReadable else { throw Failure.unreadable }

        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw Failure.unreadable
        }
        guard let track = tracks.first else { throw Failure.noAudioTrack }

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Failure.exportFailed("Could not create audio composition")
        }
        do {
            let range = try await track.load(.timeRange)
            try compositionTrack.insertTimeRange(range, of: track, at: .zero)
        } catch {
            throw Failure.exportFailed(error.localizedDescription)
        }

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw Failure.exportFailed("Audio export is not available for this file")
        }

        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: output)

        let states = session.states(updateInterval: 0.5)
        let progressTask = Task {
            for await state in states {
                if case .exporting(let exportProgress) = state {
                    progress(exportProgress.fractionCompleted)
                }
            }
        }
        defer { progressTask.cancel() }

        do {
            try await session.export(to: output, as: .m4a)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Failure.exportFailed(error.localizedDescription)
        }

        let size = (try? output.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size > 0 else { throw Failure.exportFailed("Exported audio file is empty") }
        progress(1)
    }
}

nonisolated enum MediaInfo {
    @concurrent
    static func duration(of url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let seconds = duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}
