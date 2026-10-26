import Foundation

enum DownloadQuality: String, Codable, CaseIterable {
    case standard = "Standard (128 kbps)"
    case high = "High (256 kbps)"
    case lossless = "Lossless (Hi-Fi)"

    var itag: Int {
        switch self {
        case .standard: return 139 // 64-128k
        case .high: return 140     // 128-256k
        case .lossless: return 141 // 256k+
        }
    }
}

enum OutputPrecision: String, Codable, CaseIterable {
    case pcm16 = "16-bit PCM"
    case float32 = "32-bit Float"
}

final class SettingsManager {

    static let shared = SettingsManager()
    static let didChangeNotification = Notification.Name("SettingsManagerDidChange")

    private let defaults = UserDefaults.standard

    private let keyDownloadQuality = "iMusic_downloadQuality"
    private let keyDownloadWifiOnly = "iMusic_downloadWifiOnly"
    private let keyOutputPrecision = "iMusic_outputPrecision"
    private let keyCrossfade = "iMusic_crossfade"
    private let keyPlayNextOnSwipe = "iMusic_playNextOnSwipe"
    private let keyAppLanguage = "iMusic_appLanguage"
    private let keySmartAlignment = "iMusic_smartAlignment"
    private let keyHideShorts = "iMusic_hideShorts"
    private let keySoftwareVolume = "iMusic_softwareVolume"

    private init() {}

    var downloadQuality: DownloadQuality {
        get {
            guard let raw = defaults.string(forKey: keyDownloadQuality),
                  let val = DownloadQuality(rawValue: raw) else {
                return .high
            }
            return val
        }
        set {
            defaults.set(newValue.rawValue, forKey: keyDownloadQuality)
            notifyChange()
        }
    }

    var downloadWifiOnly: Bool {
        get {
            if defaults.object(forKey: keyDownloadWifiOnly) == nil { return true }
            return defaults.bool(forKey: keyDownloadWifiOnly)
        }
        set {
            defaults.set(newValue, forKey: keyDownloadWifiOnly)
            notifyChange()
        }
    }

    var outputPrecision: OutputPrecision {
        get {
            guard let raw = defaults.string(forKey: keyOutputPrecision),
                  let val = OutputPrecision(rawValue: raw) else {
                return .pcm16
            }
            return val
        }
        set {
            defaults.set(newValue.rawValue, forKey: keyOutputPrecision)
            notifyChange()
        }
    }

    var crossfadeDuration: Double {
        get {
            return defaults.double(forKey: keyCrossfade) // default 0.0s (off)
        }
        set {
            defaults.set(newValue, forKey: keyCrossfade)
            notifyChange()
        }
    }

    var playNextOnSwipe: Bool {
        get {
            if defaults.object(forKey: keyPlayNextOnSwipe) == nil { return true }
            return defaults.bool(forKey: keyPlayNextOnSwipe)
        }
        set {
            defaults.set(newValue, forKey: keyPlayNextOnSwipe)
            notifyChange()
        }
    }

    var appLanguage: String {
        get {
            return defaults.string(forKey: keyAppLanguage) ?? "English"
        }
        set {
            defaults.set(newValue, forKey: keyAppLanguage)
            notifyChange()
        }
    }

    var smartAudioAlignment: Bool {
        get {
            if defaults.object(forKey: keySmartAlignment) == nil { return true }
            return defaults.bool(forKey: keySmartAlignment)
        }
        set {
            defaults.set(newValue, forKey: keySmartAlignment)
            notifyChange()
        }
    }

    var hideShorts: Bool {
        get {
            return defaults.bool(forKey: keyHideShorts)
        }
        set {
            defaults.set(newValue, forKey: keyHideShorts)
            notifyChange()
        }
    }

    var softwareVolume: Float {
        get {
            if defaults.object(forKey: keySoftwareVolume) == nil { return 1.0 }
            return defaults.float(forKey: keySoftwareVolume)
        }
        set {
            defaults.set(newValue, forKey: keySoftwareVolume)
            notifyChange()
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: SettingsManager.didChangeNotification, object: nil)
    }
}
