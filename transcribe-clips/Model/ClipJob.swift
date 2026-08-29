import CoreGraphics
import Foundation
import Observation

@Observable
final class ClipJob: Identifiable {
    enum Status: Equatable {
        case idle
        case queued
        case extracting(Double)
        case uploading(Double)
        case transcribing
        case waitingToRetry(Int)
        case writing
        case done(cues: Int)
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let url: URL
    let relativeName: String
    var duration: TimeInterval?
    var thumbnail: CGImage?
    var mediaInfoLoaded = false
    var isSelected: Bool
    var hasExistingSRT: Bool
    let nameCollision: Bool
    var status: Status = .idle

    init(url: URL, relativeName: String, hasExistingSRT: Bool, nameCollision: Bool) {
        self.url = url
        self.relativeName = relativeName
        self.hasExistingSRT = hasExistingSRT
        self.nameCollision = nameCollision
        self.isSelected = !hasExistingSRT && !nameCollision
    }

    var srtURL: URL { url.deletingPathExtension().appendingPathExtension("srt") }
    var jsonURL: URL { url.deletingPathExtension().appendingPathExtension("transcript.json") }

    var isSelectable: Bool { !hasExistingSRT && !nameCollision && !isActive }
    var isDimmed: Bool { hasExistingSRT || nameCollision }

    var isActive: Bool {
        switch status {
        case .queued, .extracting, .uploading, .transcribing, .waitingToRetry, .writing: return true
        default: return false
        }
    }

    var isFailedOrCancelled: Bool {
        switch status {
        case .failed, .cancelled: return true
        default: return false
        }
    }

    var durationText: String {
        guard let duration else { return "–" }
        return Duration.seconds(duration).formatted(.time(pattern: duration >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }

    /// Progress callbacks arrive asynchronously; ignore ones that belong to a stage we've already left.
    func applyProgress(_ update: Status) {
        switch (status, update) {
        case (.extracting(let old), .extracting(let new)):
            if new - old >= 0.01 || new >= 1 { status = update }
        case (.uploading(let old), .uploading(let new)):
            if new - old >= 0.01 || new >= 1 { status = update }
        case (.uploading, .transcribing), (.waitingToRetry, .transcribing), (.waitingToRetry, .uploading):
            status = update
        case (.uploading, .waitingToRetry), (.transcribing, .waitingToRetry), (.waitingToRetry, .waitingToRetry):
            status = update
        default:
            break
        }
    }
}
