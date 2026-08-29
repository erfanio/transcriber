import SwiftUI

/// In-app version of USER-GUIDE.md; keep the two in step when the workflow changes.
struct UserGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("How to use Clip Transcriber")
                    .font(.largeTitle.bold())
                Text("Clip Transcriber creates an .srt subtitle file next to each video clip so it can be imported into DaVinci Resolve.")
                    .foregroundStyle(.secondary)

                GuideSection(title: "1. One-time setup", steps: [
                    "Open Settings (⌘,) and paste the API key you were given into “API key”, then press “Test Key” — you should see a green check.",
                    "Set “Spoken language” to Persian.",
                    "Optional: under “Names and special words”, list the characters and places in the film, one per line. It helps the transcription spell them correctly.",
                ])

                GuideSection(title: "2. Make subtitles", steps: [
                    "Drop the folder that contains the clips onto the window, or press ⌘O and choose it. Subfolders are included.",
                    "Tick the clips you want (or press “Select All”). Clips that already have subtitles are greyed out.",
                    "Press Start. Each clip goes: Extracting audio → Uploading → Transcribing → Done.",
                    "When it finishes, every clip has an .srt file (and a .transcript.json) next to it.",
                ])

                GuideSection(title: "3. Import into DaVinci Resolve", steps: [
                    "Right-click in the Media Pool → Import → Subtitle…, choose the .srt and drag it onto the timeline.",
                ])

                GuideSection(title: "Tips", steps: [
                    "Keep the laptop lid open while it works; the app can run in the background.",
                    "If the app is closed mid-way, open the same folder again and tick the remaining clips.",
                    "To redo a clip, delete its .srt in Finder — the list updates by itself. If the clip still has its .transcript.json, subtitles are rebuilt instantly without uploading again. That is also how to apply new subtitle settings to clips you have already done.",
                    "Use the globe button to switch the app between English and Persian.",
                ])
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minWidth: 520, minHeight: 480)
    }
}

private struct GuideSection: View {
    let title: LocalizedStringKey
    let steps: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.bold())
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .trailing)
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    UserGuideView()
}
