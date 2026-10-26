import Foundation

enum DownloadQuality: String, Codable, CaseIterable {
    case standard = "Standard AAC (about 48 kbps, when available)"
    case high = "High AAC (about 128 kbps, when available)"

    var itag: Int {
        switch self {
        case .standard: return 139
        case .high: return 140
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
    private let keyProgressiveBuffering = "iMusic_progressiveBuffering"
    private let keyStreamOnCellular = "iMusic_streamOnCellular"
    private let keyAudioCacheEnabled = "iMusic_audioCacheEnabled"
    private let keyAudioCacheLimitMB = "iMusic_audioCacheLimitMB"

    private init() {}

    var downloadQuality: DownloadQuality {
        get {
            guard let raw = defaults.string(forKey: keyDownloadQuality) else { return .high }
            if let value = DownloadQuality(rawValue: raw) { return value }
            let migrated: DownloadQuality = raw == "Standard (128 kbps)" ? .standard : .high
            defaults.set(migrated.rawValue, forKey: keyDownloadQuality)
            return migrated
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

    /// When on, playback starts from a partially cached file and the rest keeps loading
    /// in the background. When off, a track is fully cached before it starts.
    var progressiveBuffering: Bool {
        get {
            if defaults.object(forKey: keyProgressiveBuffering) == nil { return true }
            return defaults.bool(forKey: keyProgressiveBuffering)
        }
        set {
            defaults.set(newValue, forKey: keyProgressiveBuffering)
            notifyChange()
        }
    }

    /// Streaming over cellular. Off by default to match the Wi-Fi-only download policy,
    /// but it must not silently block caching of a track the user explicitly played.
    var streamOnCellular: Bool {
        get {
            if defaults.object(forKey: keyStreamOnCellular) == nil { return true }
            return defaults.bool(forKey: keyStreamOnCellular)
        }
        set {
            defaults.set(newValue, forKey: keyStreamOnCellular)
            notifyChange()
        }
    }

    var audioCacheEnabled: Bool {
        get {
            if defaults.object(forKey: keyAudioCacheEnabled) == nil { return true }
            return defaults.bool(forKey: keyAudioCacheEnabled)
        }
        set {
            defaults.set(newValue, forKey: keyAudioCacheEnabled)
            notifyChange()
        }
    }

    /// Cache budget in megabytes; 0 means unlimited.
    var audioCacheLimitMB: Int {
        get {
            if defaults.object(forKey: keyAudioCacheLimitMB) == nil { return 512 }
            return defaults.integer(forKey: keyAudioCacheLimitMB)
        }
        set {
            defaults.set(newValue, forKey: keyAudioCacheLimitMB)
            notifyChange()
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: SettingsManager.didChangeNotification, object: nil)
    }
}
