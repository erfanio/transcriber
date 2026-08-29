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
                Text(job.relativeName)
                    .foregroundStyle(job.isDimmed ? .secondary : .primary)
                    .help(job.url.path(percentEncoded: false))
            }

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
