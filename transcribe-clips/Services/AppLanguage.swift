import AppKit
import Foundation

/// Per-app UI language, stored the same way System Settings ▸ Language & Region ▸ Applications does it.
/// Takes effect on the next launch, so `relaunch()` restarts the app.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case persian = "fa"

    var id: String { rawValue }

    /// Shown in its own language so it is recognisable whatever the current UI language is.
    var menuTitle: String {
        switch self {
        case .system: return String(localized: "Follow system language")
        case .english: return "English"
        case .persian: return "فارسی"
        }
    }

    static var current: AppLanguage {
        guard let first = UserDefaults.standard.array(forKey: "AppleLanguages")?.first as? String else { return .system }
        return AppLanguage(rawValue: String(first.prefix(2))) ?? .system
    }

    static func apply(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { quit() }
        }
    }

    /// `terminate` can be ignored (e.g. while a system dialog is pending); nothing needs saving, so force it.
    static func quit() {
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
    }
}
