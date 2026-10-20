import Foundation
import Combine

/// Manages application-wide browsing preferences and privacy settings
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

    private struct Keys {
        static let searchEngine = "seltos_pref_search_engine"
        static let enforceHTTPSOnly = "seltos_pref_enforce_https"
        static let requestDesktopSites = "seltos_pref_desktop_sites"
        static let blockPopups = "seltos_pref_block_popups"
        static let blockAdsAndTrackers = "seltos_pref_block_ads"
        static let allowInlineMediaPlayback = "seltos_pref_inline_media"
    }

    public init() {
        let savedEngineRaw = UserDefaults.standard.string(forKey: Keys.searchEngine) ?? SearchEngine.google.rawValue
        self.searchEngine = SearchEngine(rawValue: savedEngineRaw) ?? .google
        self.enforceHTTPSOnly = UserDefaults.standard.object(forKey: Keys.enforceHTTPSOnly) as? Bool ?? true
        self.requestDesktopSites = UserDefaults.standard.bool(forKey: Keys.requestDesktopSites)
        self.blockPopups = UserDefaults.standard.object(forKey: Keys.blockPopups) as? Bool ?? true
        self.blockAdsAndTrackers = UserDefaults.standard.object(forKey: Keys.blockAdsAndTrackers) as? Bool ?? true
        self.allowInlineMediaPlayback = UserDefaults.standard.object(forKey: Keys.allowInlineMediaPlayback) as? Bool ?? true
    }

    public func resetToDefaults() {
        searchEngine = .google
        enforceHTTPSOnly = true
        requestDesktopSites = false
        blockPopups = true
        blockAdsAndTrackers = true
        allowInlineMediaPlayback = true
    }
}
