import SwiftUI

struct FooterView: View {
    @Environment(JobRunner.self) private var runner

    var body: some View {
        HStack(spacing: 16) {
            Text("\(runner.selectedCount) selected")
            if runner.selectedDuration > 0 {
                Text(Self.format(runner.selectedDuration))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if runner.doneCount > 0 {
                Label("\(runner.doneCount) done", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }
            if runner.failedCount > 0 {
                Label("\(runner.failedCount) failed", systemImage: "xmark.octagon")
                    .foregroundStyle(.red)
            }
            if runner.isRunning {
                ProgressView().controlSize(.small)
                Text("Transcribing…").foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    static func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}
