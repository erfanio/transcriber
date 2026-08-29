import SwiftUI

@main
struct ClipTranscriberApp: App {
    @State private var settings: AppSettings
    @State private var runner: JobRunner
    @Environment(\.openWindow) private var openWindow

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _runner = State(initialValue: JobRunner(settings: settings))
        TempFiles.sweep()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(runner)
                .frame(minWidth: 640, minHeight: 400)
        }
        .defaultSize(width: 900, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") { runner.chooseFolder() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .help) {
                Button("Clip Transcriber User Guide") { openWindow(id: "guide") }
                    .keyboardShortcut("?", modifiers: .command)
            }
        }

        Window("User Guide", id: "guide") {
            UserGuideView()
        }
        .defaultSize(width: 680, height: 720)

        Settings {
            SettingsView()
                .environment(settings)
        }
    }
}
