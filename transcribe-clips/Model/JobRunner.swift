import AppKit
import Foundation
import Observation
import TranscribeCore
import UserNotifications
import os

private let log = Logger(subsystem: "io.erfan.transcribe-clips", category: "JobRunner")

/// Owns the clip list for the open folder and drives the extract → transcribe → write pipeline.
@Observable
final class JobRunner {
    private(set) var folderURL: URL?
    private(set) var jobs: [ClipJob] = []
    private(set) var isRunning = false
    private(set) var isScanning = false
    var lastError: String?

    private let settings: AppSettings
    private var runTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var watcher: FolderWatcher?

    init(settings: AppSettings) {
        self.settings = settings
    }

    #if DEBUG
    /// Command-line driving for automated checks: `-openFolder <path> -autoStart YES -quitWhenDone YES`.
    func applyLaunchArguments() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "apiKeyStoreSelfTest") {
            let store = APIKeyStore()
            var report: [String] = []
            do {
                try store.write("secret-\(Int.random(in: 1000...9999))", account: "selftest")
                report.append("write ok")
                report.append("read: \(try store.read(account: "selftest") ?? "nil")")
                try store.delete(account: "selftest")
                report.append("after delete: \(try store.read(account: "selftest") ?? "nil")")
            } catch {
                report.append("error: \(error)")
            }
            try? report.joined(separator: "\n").write(to: TempFiles.directory.appending(path: "apikeystore-selftest.txt"), atomically: true, encoding: .utf8)
            AppLanguage.quit()
            return
        }
        if let code = defaults.string(forKey: "switchLanguage"), let language = AppLanguage(rawValue: code) {
            AppLanguage.apply(language)
            DebugReport.append("switchLanguage \(code) -> AppleLanguages=\(defaults.array(forKey: "AppleLanguages") ?? [])")
            AppLanguage.relaunch()
            return
        }
        guard let path = defaults.string(forKey: "openFolder") else { return }
        openFolder(URL(fileURLWithPath: path, isDirectory: true))
        guard defaults.bool(forKey: "autoStart") else { return }
        Task {
            while isScanning { try? await Task.sleep(for: .milliseconds(100)) }
            selectAll()
            start()
            while isRunning { try? await Task.sleep(for: .milliseconds(200)) }
            if defaults.bool(forKey: "quitWhenDone") { AppLanguage.quit() }
        }
    }
    #endif

    // MARK: - Derived counts

    var selectedJobs: [ClipJob] { jobs.filter { $0.isSelected && $0.isSelectable } }
    var selectedCount: Int { selectedJobs.count }
    var selectedDuration: TimeInterval { selectedJobs.compactMap(\.duration).reduce(0, +) }
    var doneCount: Int { jobs.filter { if case .done = $0.status { true } else { false } }.count }
    var failedCount: Int { jobs.filter(\.isFailedOrCancelled).count }

    // MARK: - Folder selection

    func chooseFolder() {
        guard !isRunning else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose the folder that contains your video clips")
        panel.prompt = String(localized: "Choose")
        Task {
            guard await panel.begin() == .OK, let url = panel.url else { return }
            openFolder(url)
        }
    }

    func handleDrop(_ urls: [URL]) -> Bool {
        guard !isRunning else { return false }
        let folders = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        guard let folder = folders.first else {
            lastError = String(localized: "Please drop a folder, not individual files. Subtitles are saved next to the clips inside the folder.")
            return false
        }
        openFolder(folder)
        return true
    }

    func openFolder(_ url: URL) {
        scanTask?.cancel()
        refreshTask?.cancel()
        folderURL = url
        jobs = []
        isScanning = true
        watcher = FolderWatcher(folder: url) { [weak self] in self?.folderChanged() }
        scanTask = Task {
            let clips = await MediaScanner.scan(folder: url)
            guard !Task.isCancelled else { return }
            jobs = clips.map(makeJob)
            isScanning = false
            await loadMediaInfo(for: jobs)
        }
    }

    /// Re-scan the open folder, keeping existing rows (and their state) where the clip is still there.
    func refresh() {
        guard let folderURL, !isRunning, !isScanning else { return }
        refreshTask?.cancel()
        refreshTask = Task {
            let clips = await MediaScanner.scan(folder: folderURL)
            guard !Task.isCancelled, !isRunning, self.folderURL == folderURL else { return }
            var existing = Dictionary(jobs.map { ($0.url.standardizedFileURL.path(percentEncoded: false), $0) }, uniquingKeysWith: { first, _ in first })
            var updated: [ClipJob] = []
            var added: [ClipJob] = []
            for clip in clips {
                if let job = existing.removeValue(forKey: clip.url.standardizedFileURL.path(percentEncoded: false)) {
                    job.update(from: clip)
                    updated.append(job)
                } else {
                    let job = makeJob(clip)
                    updated.append(job)
                    added.append(job)
                }
            }
            jobs = updated
            log.notice("refresh: \(updated.count) clips, \(updated.filter(\.hasExistingSRT).count) with subtitles, \(added.count) new, \(existing.count) removed")
            DebugReport.append("refresh: \(updated.count) clips, \(updated.filter(\.hasExistingSRT).count) with subtitles, \(added.count) new, \(existing.count) removed")
            await loadMediaInfo(for: added)
        }
    }

    private func folderChanged() {
        DebugReport.append("folderChanged isRunning=\(isRunning) isScanning=\(isScanning)")
        guard !isRunning else { return }
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    private func makeJob(_ clip: ScannedClip) -> ClipJob {
        ClipJob(
            url: clip.url,
            relativeName: clip.relativeName,
            hasExistingSRT: clip.hasExistingSRT,
            hasSavedTranscript: clip.hasSavedTranscript,
            nameCollision: clip.nameCollision
        )
    }

    /// Durations and thumbnails, a few clips at a time so a big folder fills in progressively.
    private func loadMediaInfo(for jobs: [ClipJob]) async {
        var pending = jobs.makeIterator()
        await withTaskGroup(of: (UUID, TimeInterval?, CGImage?).self) { group in
            func enqueueNext() {
                guard let job = pending.next() else { return }
                let id = job.id, url = job.url
                group.addTask {
                    async let duration = MediaInfo.duration(of: url)
                    async let thumbnail = MediaInfo.thumbnail(of: url)
                    return await (id, duration, thumbnail)
                }
            }
            for _ in 0..<3 { enqueueNext() }
            for await (id, duration, thumbnail) in group {
                guard !Task.isCancelled else { return }
                if let job = jobs.first(where: { $0.id == id }) {
                    job.duration = duration
                    job.thumbnail = thumbnail
                    job.mediaInfoLoaded = true
                }
                enqueueNext()
            }
        }
    }

    // MARK: - Selection

    func setSelected(_ selected: Bool, for job: ClipJob) {
        guard job.isSelectable else { return }
        job.isSelected = selected
    }

    func selectAll() {
        for job in jobs where job.isSelectable { job.isSelected = true }
    }

    func selectNone() {
        for job in jobs where job.isSelectable { job.isSelected = false }
    }

    // MARK: - Running

    func start() {
        guard !isRunning else { return }
        let queue = selectedJobs
        guard !queue.isEmpty else { return }

        let apiKey: String?
        do {
            apiKey = try APIKeyStore().read(account: settings.providerID)
        } catch {
            lastError = String(localized: "Could not read the saved API key: \(error.localizedDescription)")
            return
        }
        let config = settings.runConfiguration(apiKey: apiKey)
        let provider: any TranscriptionProvider
        do {
            provider = try ProviderFactory.make(config)
        } catch let error as TranscriptionError {
            lastError = ErrorMessages.text(for: error)
            return
        } catch {
            lastError = error.localizedDescription
            return
        }

        for job in queue { job.status = .queued }
        isRunning = true
        Notifier.requestPermissionIfNeeded()
        runTask = Task {
            await run(queue, config: config, provider: provider)
            isRunning = false
            refresh()
            Notifier.batchFinished(done: queue.filter { if case .done = $0.status { true } else { false } }.count,
                                   failed: queue.filter(\.isFailedOrCancelled).count)
        }
    }

    func cancel() {
        runTask?.cancel()
    }

    func retryFailed() {
        for job in jobs where job.isFailedOrCancelled {
            job.status = .idle
            job.isSelected = true
        }
        start()
    }

    private func run(_ queue: [ClipJob], config: RunConfiguration, provider: any TranscriptionProvider) async {
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Transcribing clips"
        )
        defer { ProcessInfo.processInfo.endActivity(activity) }

        let extractGate = AsyncSemaphore(limit: 2)
        let networkGate = AsyncSemaphore(limit: config.maxConcurrent)

        await withTaskGroup(of: Void.self) { group in
            for job in queue {
                group.addTask {
                    await self.process(job, config: config, provider: provider, extractGate: extractGate, networkGate: networkGate)
                }
            }
        }
    }

    private func process(
        _ job: ClipJob,
        config: RunConfiguration,
        provider: any TranscriptionProvider,
        extractGate: AsyncSemaphore,
        networkGate: AsyncSemaphore
    ) async {
        let audioURL = TempFiles.directory.appending(path: "\(job.id.uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let sourceURL = job.url

        do {
            try Task.checkCancellation()
            let transcript: Transcript
            if job.canRebuildLocally, let saved = await SubtitleBuilder.loadTranscript(from: job.jsonURL) {
                log.notice("rebuilding \(job.relativeName, privacy: .public) from saved transcript")
                transcript = saved
            } else {
                job.status = .extracting(0)
                try await extractGate.withPermit {
                    try await AudioExtractor.extractAudio(from: sourceURL, to: audioURL) { fraction in
                        Task { @MainActor in job.applyProgress(.extracting(fraction)) }
                    }
                }

                job.status = .uploading(0)
                let options = config.transcriptionOptions
                transcript = try await networkGate.withPermit {
                    try await provider.transcribe(audioFileURL: audioURL, options: options) { update in
                        Task { @MainActor in
                            switch update {
                            case .uploading(let fraction): job.applyProgress(.uploading(fraction))
                            case .processing: job.applyProgress(.transcribing)
                            case .waitingToRetry(let seconds): job.applyProgress(.waitingToRetry(Int(seconds.rounded(.up))))
                            }
                        }
                    }
                }
                if config.saveRawTranscript {
                    try SubtitleBuilder.transcriptData(transcript).write(to: job.jsonURL, options: .atomic)
                    job.hasSavedTranscript = true
                }
            }

            job.status = .writing
            let (srt, cueCount) = await SubtitleBuilder.build(transcript, options: config.segmenterOptions, srtOptions: config.srtOptions)
            try Data(srt.utf8).write(to: job.srtURL, options: .atomic)
            job.status = .done(cues: cueCount)
            job.hasExistingSRT = true
            job.isSelected = false
        } catch is CancellationError {
            job.status = .cancelled
        } catch let error as AudioExtractor.Failure {
            job.status = .failed(ErrorMessages.text(for: error))
        } catch let error as TranscriptionError {
            job.status = .failed(ErrorMessages.text(for: error))
        } catch {
            job.status = .failed(error.localizedDescription)
        }
    }
}

nonisolated enum SubtitleBuilder {
    @concurrent
    static func build(_ transcript: Transcript, options: SegmenterOptions, srtOptions: SRTWriter.Options) async -> (srt: String, cueCount: Int) {
        let cues = SubtitleSegmenter.segment(transcript.words, options: options)
        return (SRTWriter.render(cues, options: srtOptions), cues.count)
    }

    /// nil if the file is missing or not something we wrote; the caller then transcribes normally.
    @concurrent
    static func loadTranscript(from url: URL) async -> Transcript? {
        guard let data = try? Data(contentsOf: url),
              let transcript = try? JSONDecoder().decode(Transcript.self, from: data),
              !transcript.words.isEmpty
        else { return nil }
        return transcript
    }

    static func transcriptData(_ transcript: Transcript) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(transcript)
    }
}

/// Appends to a file in the temp dir when launched with `-debugReport YES`, for automated checks.
nonisolated enum DebugReport {
    static func append(_ line: String) {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "debugReport") else { return }
        let url = TempFiles.directory.appending(path: "debug-report.txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
        #endif
    }
}

nonisolated enum TempFiles {
    static var directory: URL {
        URL.temporaryDirectory.appending(path: "transcribe-clips", directoryHint: .isDirectory)
    }

    static func sweep() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

enum Notifier {
    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func batchFinished(done: Int, failed: Int) {
        guard !NSApp.isActive || true else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Transcription finished")
        content.body = failed == 0
            ? String(localized: "\(done) clips now have subtitles.")
            : String(localized: "\(done) clips done, \(failed) failed.")
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
