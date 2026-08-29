import SwiftUI
import TranscribeCore

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var apiKey = ""
    @State private var storedKey = ""
    @State private var keyCheck: KeyCheck = .idle
    @State private var keyCheckTask: Task<Void, Never>?

    private enum KeyCheck: Equatable {
        case idle, testing, ok(String), failed(String)
    }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Transcription service") {
                Picker("Service", selection: $settings.providerID) {
                    ForEach(ProviderFactory.available) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                if ProviderFactory.info(for: settings.providerID)?.needsAPIKey == true {
                    SecureField("API key", text: $apiKey)
                        .textContentType(.password)
                        .onSubmit(saveKey)
                    HStack {
                        Button("Test Key") { testKey() }
                            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || keyCheck == .testing)
                        keyCheckLabel
                    }
                    Text("The key is stored in your keychain when you press Test Key or close this window.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if settings.providerID == ProviderFactory.elevenLabsID {
                        Link("Get an ElevenLabs API key…", destination: URL(string: "https://elevenlabs.io/app/settings/api-keys")!)
                            .font(.callout)
                    }
                }
            }

            Section("Language") {
                Picker("Spoken language", selection: $settings.languageCode) {
                    ForEach(AppSettings.languages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
            }

            Section("Subtitles") {
                Stepper(value: $settings.maxCharsPerLine, in: 20...60) {
                    LabeledContent("Characters per line", value: "\(settings.maxCharsPerLine)")
                }
                Stepper(value: $settings.maxCueDuration, in: 2...10, step: 0.5) {
                    LabeledContent("Longest subtitle", value: "\(settings.maxCueDuration.formatted()) s")
                }
                Toggle("Detect different speakers", isOn: $settings.diarize)
                Toggle("Keep a copy of the full transcript (.transcript.json)", isOn: $settings.saveRawTranscript)
            }

            Section {
                TextEditor(text: $settings.keytermsText)
                    .font(.body)
                    .frame(minHeight: 70)
            } header: {
                Text("Names and special words")
            } footer: {
                Text("One per line. Character names, places and unusual words help the transcription get spelling right.")
                    .foregroundStyle(.secondary)
            }

            Section("Advanced") {
                Stepper(value: $settings.maxConcurrent, in: 1...4) {
                    LabeledContent("Clips transcribed at once", value: "\(settings.maxConcurrent)")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: loadKey)
        .onDisappear(perform: saveKey)
        .onChange(of: settings.providerID) { _, _ in
            saveKey()
            loadKey()
        }
    }

    @ViewBuilder
    private var keyCheckLabel: some View {
        switch keyCheck {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView().controlSize(.small)
        case .ok(let summary):
            Label(summary, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private func loadKey() {
        guard ProviderFactory.info(for: settings.providerID)?.needsAPIKey == true else {
            apiKey = ""
            storedKey = ""
            return
        }
        do {
            storedKey = try KeychainStore().read(account: settings.providerID) ?? ""
            apiKey = storedKey
            keyCheck = .idle
        } catch {
            keyCheck = .failed(String(localized: "Could not read the key: \(error.localizedDescription)"))
        }
    }

    // Keychain access can prompt on ad-hoc builds, so only touch it when the key actually changed.
    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != storedKey, ProviderFactory.info(for: settings.providerID)?.needsAPIKey == true else { return }
        do {
            if trimmed.isEmpty {
                try KeychainStore().delete(account: settings.providerID)
            } else {
                try KeychainStore().write(trimmed, account: settings.providerID)
            }
            storedKey = trimmed
        } catch {
            keyCheck = .failed(String(localized: "Could not save the key: \(error.localizedDescription)"))
        }
    }

    private func testKey() {
        saveKey()
        keyCheckTask?.cancel()
        keyCheck = .testing
        let config = settings.runConfiguration(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        keyCheckTask = Task {
            do {
                let provider = try ProviderFactory.make(config)
                let summary = try await provider.validateCredentials()
                keyCheck = .ok(summary)
            } catch let error as TranscriptionError {
                keyCheck = .failed(ErrorMessages.text(for: error))
            } catch {
                keyCheck = .failed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}
