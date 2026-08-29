import AppKit
import SwiftUI

struct ClipTable: View {
    @Environment(JobRunner.self) private var runner
    @State private var selection = Set<ClipJob.ID>()

    var body: some View {
        Table(runner.jobs, selection: $selection) {
            TableColumn("") { job in
                Toggle("", isOn: Binding(
                    get: { job.isSelected },
                    set: { runner.setSelected($0, for: job) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!job.isSelectable || runner.isRunning)
            }
            .width(28)

            TableColumn("Clip") { job in
                HStack(spacing: 10) {
                    ThumbnailView(job: job)
                    Text(job.relativeName)
                        .foregroundStyle(job.isDimmed ? .secondary : .primary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 4)
                .help(job.url.path(percentEncoded: false))
            }
            .width(min: 260, ideal: 360)

            TableColumn("Duration") { job in
                Text(job.durationText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(80)

            TableColumn("Status") { job in
                StatusCell(job: job)
            }
            .width(min: 220, ideal: 320)
        }
        .contextMenu(forSelectionType: ClipJob.ID.self) { ids in
            Button("Show in Finder") {
                let urls = runner.jobs.filter { ids.contains($0.id) }.map(\.url)
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }
        }
        .overlay {
            if !runner.isScanning, runner.jobs.isEmpty {
                ContentUnavailableView(
                    "No video or audio clips found",
                    systemImage: "film",
                    description: Text("This folder (including subfolders) has no clips the app can read.")
                )
            }
        }
    }
}

private struct ThumbnailView: View {
    let job: ClipJob
    private let size = CGSize(width: 96, height: 54)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(.quaternary)
            if let thumbnail = job.thumbnail {
                Image(thumbnail, scale: 1, label: Text(job.relativeName))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: job.mediaInfoLoaded ? "waveform" : "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .opacity(job.isDimmed ? 0.5 : 1)
    }
}

private struct StatusCell: View {
    let job: ClipJob

    var body: some View {
        HStack(spacing: 8) {
            switch job.status {
            case .idle:
                if job.hasExistingSRT {
                    Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                    Text("Subtitles exist").foregroundStyle(.secondary)
                } else if job.nameCollision {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text("Same name as another clip").foregroundStyle(.secondary)
                } else if job.canRebuildLocally {
                    Image(systemName: "doc.text").foregroundStyle(.secondary)
                    Text("Will rebuild from the saved transcript (no upload)").foregroundStyle(.secondary)
                } else {
                    Text("Ready").foregroundStyle(.secondary)
                }
            case .queued:
                Text("Waiting…").foregroundStyle(.secondary)
            case .extracting(let fraction):
                ProgressView(value: fraction).frame(width: 90)
                Text("Extracting audio")
            case .uploading(let fraction):
                ProgressView(value: fraction).frame(width: 90)
                Text("Uploading")
            case .transcribing:
                ProgressView().controlSize(.small)
                Text("Transcribing…")
            case .waitingToRetry(let seconds):
                ProgressView().controlSize(.small)
                Text("Busy — retrying in \(seconds) s")
            case .writing:
                ProgressView().controlSize(.small)
                Text("Saving subtitles")
            case .done(let cues):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Done · \(cues) subtitles")
            case .failed(let message):
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                Text(message).lineLimit(1).truncationMode(.tail).help(message)
            case .cancelled:
                Image(systemName: "minus.circle").foregroundStyle(.secondary)
                Text("Cancelled").foregroundStyle(.secondary)
            }
        }
    }
}
