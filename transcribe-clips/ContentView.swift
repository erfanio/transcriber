import SwiftUI

struct ContentView: View {
    @Environment(JobRunner.self) private var runner
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if runner.folderURL == nil {
                EmptyStateView()
            } else {
                VStack(spacing: 0) {
                    FolderHeader()
                    Divider()
                    ClipTable()
                    Divider()
                    FooterView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            runner.handleDrop(urls)
        } isTargeted: { isDropTargeted = $0 }
        .navigationTitle(runner.folderURL?.lastPathComponent ?? String(localized: "Clip Transcriber"))
        .task {
            #if DEBUG
            runner.applyLaunchArguments()
            #endif
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    runner.chooseFolder()
                } label: {
                    Label("Open Folder…", systemImage: "folder")
                }
                .disabled(runner.isRunning)
                .help("Choose a folder of video clips")

                if runner.isRunning {
                    Button(role: .destructive) {
                        runner.cancel()
                    } label: {
                        Label("Cancel", systemImage: "stop.fill")
                    }
                    .help("Stop transcribing")
                } else {
                    Button {
                        runner.start()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .disabled(runner.selectedCount == 0)
                    .help("Transcribe the ticked clips")

                    if runner.failedCount > 0 {
                        Button {
                            runner.retryFailed()
                        } label: {
                            Label("Retry Failed", systemImage: "arrow.clockwise")
                        }
                    }
                }

                LanguageMenu()
                    .disabled(runner.isRunning)

                Button {
                    openWindow(id: "guide")
                } label: {
                    Label("User Guide", systemImage: "book")
                }
                .help("How to use the app, step by step")

                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("API key, language and subtitle options")
            }
        }
        .alert(
            String(localized: "Something went wrong"),
            isPresented: Binding(get: { runner.lastError != nil }, set: { if !$0 { runner.lastError = nil } }),
            actions: { Button("OK") { runner.lastError = nil } },
            message: { Text(runner.lastError ?? "") }
        )
    }
}

private struct LanguageMenu: View {
    @State private var pending: AppLanguage?

    var body: some View {
        Menu {
            Picker(selection: Binding(get: { AppLanguage.current }, set: { pending = $0 })) {
                ForEach(AppLanguage.allCases) { language in
                    Text(verbatim: language.menuTitle).tag(language)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            Label("App language", systemImage: "globe")
        }
        .help("Switch the app between English and Persian")
        .alert(
            String(localized: "Restart to switch language?"),
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { language in
            Button("Restart") {
                AppLanguage.apply(language)
                AppLanguage.relaunch()
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: { _ in
            Text("Clip Transcriber needs to restart to change its language.")
        }
    }
}

private struct EmptyStateView: View {
    @Environment(JobRunner.self) private var runner

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Drop a folder of video clips here")
                .font(.title2)
            Text("Subtitles (.srt) are saved next to each clip.")
                .foregroundStyle(.secondary)
            Button("Open Folder…") { runner.chooseFolder() }
                .keyboardShortcut("o")
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(40)
    }
}

private struct FolderHeader: View {
    @Environment(JobRunner.self) private var runner

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
            Text(runner.folderURL?.path(percentEncoded: false) ?? "")
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            if runner.isScanning {
                ProgressView().controlSize(.small)
                Text("Scanning…").foregroundStyle(.secondary)
            }
            Spacer()
            Button("Select All") { runner.selectAll() }
            Button("Select None") { runner.selectNone() }
            Button {
                runner.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")
            .help("Re-scan the folder for new clips or deleted subtitles")
        }
        .disabled(runner.isRunning)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    let settings = AppSettings(defaults: UserDefaults(suiteName: "preview")!)
    ContentView()
        .environment(settings)
        .environment(JobRunner(settings: settings))
}
