# Clip Transcriber

macOS app that transcribes a folder of video clips (Persian by default) with ElevenLabs Scribe v2 and writes an `.srt` next to each clip. Uses only what ships with macOS: SwiftUI, AVFoundation (audio extraction), URLSession, Keychain. See [USER-GUIDE.md](USER-GUIDE.md) for the end-user instructions (Persian + English).

## Layout

- `TranscribeCore/` — Swift package, pure Foundation, Swift 6 mode. Transcript models, `TranscriptionProvider` protocol, ElevenLabs provider, streamed multipart upload, retry/error mapping, subtitle segmenter and SRT writer. Fully unit-tested.
- `transcribe-clips/` — the app target (macOS 15+, sandboxed). Folder scanning, AVFoundation audio extraction, job runner, SwiftUI views, string catalogs (`en`, `fa`).

The API key is kept as an owner-only file in the app's sandbox container (`…/Data/Library/Application Support/api-keys/`) rather than the keychain: ad-hoc-signed builds can only use the legacy keychain, which demands the login password after every rebuild.

## Develop

```sh
cd TranscribeCore && swift test            # package tests, no network needed
xcodebuild -scheme transcribe-clips -configuration Debug build
```

In Debug builds the service picker also offers **Mock (offline test)**, which returns canned Persian words so the whole pipeline can be exercised without an API key. The Debug build also accepts launch arguments for automation:

```sh
open -a "Clip Transcriber.app" --args -openFolder /path/to/clips -autoStart YES -providerID mock
```

(Under the sandbox the folder must be one the app can reach on its own, e.g. inside its container.)

## Add a transcription backend

1. Implement `TranscriptionProvider` in `TranscribeCore/Sources/TranscribeCore/Provider/`.
2. Register it in `transcribe-clips/Services/ProviderFactory.swift` (id, display name, whether it needs a key).

The app takes care of audio extraction, concurrency, progress, cue segmentation and file writing.

## Release (ad-hoc, no developer account)

```sh
scripts/build-release.sh          # → build/Clip Transcriber.zip (universal, Release, ad-hoc signed)
```

Or in Xcode: destination *Any Mac* → Product → Archive → Distribute App → Custom → Copy App.

Copying from a USB stick avoids the quarantine flag entirely. If the zip arrives via AirDrop/download, the first launch on macOS 15+ needs System Settings → Privacy & Security → **Open Anyway** (right-click → Open no longer bypasses Gatekeeper there); see the user guide. `xattr -d com.apple.quarantine "Clip Transcriber.app"` is the shortcut if you set it up yourself.
