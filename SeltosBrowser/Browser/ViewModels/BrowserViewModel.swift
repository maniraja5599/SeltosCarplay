import Foundation
import Combine
import WebKit
import MediaPlayer

/// Central ViewModel coordinating browser tabs, navigation, media synchronization, and privacy
public final class BrowserViewModel: ObservableObject, MediaPlaybackControllable {
    public static let shared = BrowserViewModel()

    @Published public var urlInputText: String = ""
    @Published public var isAddressBarFocused: Bool = false
    @Published public var showTabSwitcher: Bool = false
    @Published public var showBookmarksSheet: Bool = false
    @Published public var showHistorySheet: Bool = false
    @Published public var showSettingsSheet: Bool = false

    public var tabManager = TabManager.shared
    public var bookmarkManager = BookmarkManager.shared
    public var historyManager = HistoryManager.shared
    public var settingsManager = SettingsManager.shared
    public var audioSessionManager = AudioSessionManager.shared
    public var nowPlayingManager = NowPlayingManager.shared

    private var webViews: [UUID: WKWebView] = [:]
    private var cancellables = Set<AnyCancellable>()

    public init() {
        nowPlayingManager.playbackController = self
        audioSessionManager.configureAudioSession()

        // Sync active tab URL changes into the address bar input text
        tabManager.$activeTabId
            .sink { [weak self] _ in
                self?.syncActiveTabToAddressBar()
            }
            .store(in: &cancellables)
    }

    public var activeTab: BrowserTab {
        tabManager.activeTab
    }

    public var activeWebView: WKWebView? {
        webViews[tabManager.activeTabId]
    }

    public func registerWebView(_ webView: WKWebView, for tabId: UUID) {
        webViews[tabId] = webView
    }

    // MARK: - Navigation Commands

    public func load(input: String) {
        guard let resolvedURL = WebKitSecurityPolicy.resolveInput(
            input,
            searchEngine: settingsManager.searchEngine,
            enforceHTTPS: settingsManager.enforceHTTPSOnly
        ) else {
            return
        }

        urlInputText = resolvedURL.absoluteString
        tabManager.updateActiveTab(
            url: resolvedURL,
            isLoading: true,
            errorMessage: nil,
            isSecure: WebKitSecurityPolicy.isSecureURL(resolvedURL)
        )

        if let wv = activeWebView {
            let request = URLRequest(url: resolvedURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            wv.load(request)
        }
    }

    public func loadBookmark(_ bookmark: Bookmark) {
        guard let url = bookmark.url else { return }
        load(input: url.absoluteString)
    }

    public func goBack() {
        if let wv = activeWebView, wv.canGoBack {
            wv.goBack()
        }
    }

    public func goForward() {
        if let wv = activeWebView, wv.canGoForward {
            wv.goForward()
        }
    }

    public func reload() {
        if let wv = activeWebView {
            wv.reload()
        }
    }

    public func stopLoading() {
        if let wv = activeWebView {
            wv.stopLoading()
        }
        tabManager.updateActiveTab(isLoading: false)
    }

    public func goToHome() {
        activeWebView?.load(URLRequest(url: URL(string: "about:blank")!))
        tabManager.updateActiveTab(
            title: "New Tab",
            url: nil,
            canGoBack: false,
            canGoForward: false,
            isLoading: false,
            estimatedProgress: 0.0,
            errorMessage: nil,
            isSecure: true
        )
        urlInputText = ""
        nowPlayingManager.clearNowPlaying()
    }

    public func addNewTab(with url: URL? = nil) {
        let newId = tabManager.createNewTab(with: url)
        syncActiveTabToAddressBar()
        if let url = url {
            load(input: url.absoluteString)
        }
    }

    public func closeTab(id: UUID) {
        webViews[id]?.stopLoading()
        webViews.removeValue(forKey: id)
        tabManager.closeTab(id: id)
        syncActiveTabToAddressBar()
    }

    // MARK: - Delegate Event Handlers

    public func handleDidStartLoading(for tabId: UUID) {
        if tabId == tabManager.activeTabId {
            tabManager.updateActiveTab(isLoading: true, errorMessage: nil)
        }
    }

    public func handleDidFinishLoading(for tabId: UUID, title: String?, url: URL?) {
        guard tabId == tabManager.activeTabId else { return }

        let isSecure = WebKitSecurityPolicy.isSecureURL(url)
        let pageTitle = title ?? url?.host ?? "Web Page"

        tabManager.updateActiveTab(
            title: pageTitle,
            url: url,
            isLoading: false,
            estimatedProgress: 1.0,
            errorMessage: nil,
            isSecure: isSecure
        )

        if let urlString = url?.absoluteString, urlString != "about:blank" {
            urlInputText = urlString
            historyManager.addEntry(title: pageTitle, urlString: urlString)
        }
    }

    public func handleDidFailLoading(for tabId: UUID, error: Error) {
        guard tabId == tabManager.activeTabId else { return }

        let userFriendlyMessage: String
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            userFriendlyMessage = "No Internet Connection. Please check your cellular or Wi-Fi network."
        case NSURLErrorTimedOut:
            userFriendlyMessage = "The connection timed out. The server took too long to respond."
        case NSURLErrorCannotFindHost:
            userFriendlyMessage = "Server not found. Please verify the URL or domain spelling."
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
            userFriendlyMessage = "Security Warning: A secure connection to this site cannot be established."
        default:
            userFriendlyMessage = error.localizedDescription
        }

        tabManager.updateActiveTab(
            isLoading: false,
            errorMessage: userFriendlyMessage
        )
    }

    public func handleProgress(for tabId: UUID, progress: Double) {
        if tabId == tabManager.activeTabId {
            tabManager.updateActiveTab(estimatedProgress: progress)
        }
    }

    public func handleBackForwardState(for tabId: UUID, canGoBack: Bool, canGoForward: Bool) {
        if tabId == tabManager.activeTabId {
            tabManager.updateActiveTab(canGoBack: canGoBack, canGoForward: canGoForward)
        }
    }

    public func handleMediaStateUpdate(title: String, duration: Double, currentTime: Double, isPlaying: Bool) {
        let channelOrHost = activeTab.url?.host ?? "Web Media"
        nowPlayingManager.updateNowPlaying(
            title: title,
            channelOrSite: channelOrHost,
            duration: duration,
            elapsedTime: currentTime,
            isPlaying: isPlaying
        )
    }

    // MARK: - MediaPlaybackControllable Implementation

    public func playMedia() {
        activeWebView?.evaluateJavaScript(YouTubeHelper.playScript, completionHandler: nil)
    }

    public func pauseMedia() {
        activeWebView?.evaluateJavaScript(YouTubeHelper.pauseScript, completionHandler: nil)
    }

    public func togglePlayPauseMedia() {
        activeWebView?.evaluateJavaScript(YouTubeHelper.togglePlayPauseScript, completionHandler: nil)
    }

    public func seekForward(seconds: Double) {
        activeWebView?.evaluateJavaScript(YouTubeHelper.seekScript(delta: seconds), completionHandler: nil)
    }

    public func seekBackward(seconds: Double) {
        activeWebView?.evaluateJavaScript(YouTubeHelper.seekScript(delta: -seconds), completionHandler: nil)
    }

    // MARK: - Privacy & Data Deletion

    public func clearAllBrowsingData(completion: @escaping () -> Void) {
        // Clear WebKit data store (cookies, caches, databases)
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = Date.distantPast

        dataStore.removeData(ofTypes: dataTypes, modifiedSince: dateFrom) { [weak self] in
            DispatchQueue.main.async {
                // Clear History
                self?.historyManager.clearAllHistory()
                // Stop and reset all open tabs to blank
                for (_, webView) in self?.webViews ?? [:] {
                    webView.load(URLRequest(url: URL(string: "about:blank")!))
                }
                self?.goToHome()
                completion()
            }
        }
    }

    private func syncActiveTabToAddressBar() {
        if let url = activeTab.url {
            urlInputText = url.absoluteString
        } else {
            urlInputText = ""
        }
    }
}
