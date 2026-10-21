import Foundation
import Combine

/// Configurable jump interval for media scrubbing and steering wheel controls
public enum SeekInterval: Int, CaseIterable, Identifiable, Codable {
    case fiveSeconds = 5
    case tenSeconds = 10
    case fifteenSeconds = 15
    case sixtySeconds = 60

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .fiveSeconds: return "5 Seconds (Default)"
        case .tenSeconds: return "10 Seconds"
        case .fifteenSeconds: return "15 Seconds"
        case .sixtySeconds: return "1 Minute (60s)"
        }
    }

    public var shortTitle: String {
        switch self {
        case .fiveSeconds: return "5s"
        case .tenSeconds: return "10s"
        case .fifteenSeconds: return "15s"
        case .sixtySeconds: return "1m"
        }
    }
}

/// Manages application-wide browsing preferences, media jump intervals, and privacy settings
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    @Published public var searchEngine: SearchEngine {
        didSet {
            UserDefaults.standard.set(searchEngine.rawValue, forKey: Keys.searchEngine)
        }
    }

    @Published public var enforceHTTPSOnly: Bool {
        didSet {
            UserDefaults.standard.set(enforceHTTPSOnly, forKey: Keys.enforceHTTPSOnly)
        }
    }

    @Published public var requestDesktopSites: Bool {
        didSet {
            UserDefaults.standard.set(requestDesktopSites, forKey: Keys.requestDesktopSites)
        }
    }

    @Published public var blockPopups: Bool {
        didSet {
            UserDefaults.standard.set(blockPopups, forKey: Keys.blockPopups)
        }
    }

    @Published public var blockAdsAndTrackers: Bool {
        didSet {
            UserDefaults.standard.set(blockAdsAndTrackers, forKey: Keys.blockAdsAndTrackers)
        }
    }

    @Published public var allowInlineMediaPlayback: Bool {
        didSet {
            UserDefaults.standard.set(allowInlineMediaPlayback, forKey: Keys.allowInlineMediaPlayback)
        }
    }

    @Published public var seekInterval: SeekInterval {
        didSet {
            UserDefaults.standard.set(seekInterval.rawValue, forKey: Keys.seekInterval)
            NowPlayingManager.shared.updateSeekInterval(seekInterval.rawValue)
        }
    }

    @Published public var remotePIN: String {
        didSet {
            UserDefaults.standard.set(remotePIN, forKey: Keys.remotePIN)
        }
    }

    @Published public var isRemoteEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isRemoteEnabled, forKey: Keys.isRemoteEnabled)
        }
    }

    private struct Keys {
        static let searchEngine = "seltos_pref_search_engine"
        static let enforceHTTPSOnly = "seltos_pref_enforce_https"
        static let requestDesktopSites = "seltos_pref_desktop_sites"
        static let blockPopups = "seltos_pref_block_popups"
        static let blockAdsAndTrackers = "seltos_pref_block_ads"
        static let allowInlineMediaPlayback = "seltos_pref_inline_media"
        static let seekInterval = "seltos_pref_seek_interval"
        static let remotePIN = "seltos_pref_remote_pin"
        static let isRemoteEnabled = "seltos_pref_remote_enabled"
    }

    public init() {
        let savedEngineRaw = UserDefaults.standard.string(forKey: Keys.searchEngine) ?? SearchEngine.google.rawValue
        self.searchEngine = SearchEngine(rawValue: savedEngineRaw) ?? .google
        self.enforceHTTPSOnly = UserDefaults.standard.object(forKey: Keys.enforceHTTPSOnly) as? Bool ?? true
        self.requestDesktopSites = UserDefaults.standard.bool(forKey: Keys.requestDesktopSites)
        self.blockPopups = UserDefaults.standard.object(forKey: Keys.blockPopups) as? Bool ?? true
        self.blockAdsAndTrackers = UserDefaults.standard.object(forKey: Keys.blockAdsAndTrackers) as? Bool ?? true
        self.allowInlineMediaPlayback = UserDefaults.standard.object(forKey: Keys.allowInlineMediaPlayback) as? Bool ?? true

        let savedSeek = UserDefaults.standard.integer(forKey: Keys.seekInterval)
        self.seekInterval = SeekInterval(rawValue: savedSeek) ?? .fiveSeconds

        let savedPIN = UserDefaults.standard.string(forKey: Keys.remotePIN) ?? "5599"
        self.remotePIN = savedPIN

        self.isRemoteEnabled = UserDefaults.standard.object(forKey: Keys.isRemoteEnabled) as? Bool ?? true
    }

    public func resetToDefaults() {
        searchEngine = .google
        enforceHTTPSOnly = true
        requestDesktopSites = false
        blockPopups = true
        blockAdsAndTrackers = true
        allowInlineMediaPlayback = true
        seekInterval = .fiveSeconds
        remotePIN = "5599"
        isRemoteEnabled = true
    }
}
