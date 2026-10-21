import SwiftUI
import WebKit

/// SwiftUI wrapper around WKWebView configured for full media, inline playback, security, and fullscreen
public struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    let tabId: UUID

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.applicationNameForUserAgent = "Version/17.5 Safari/605.1.15"

        if #available(iOS 15.4, *) {
            configuration.preferences.isElementFullscreenEnabled = true
        }

        let isDesktop = viewModel.settingsManager.requestDesktopSites
        configuration.defaultWebpagePreferences.preferredContentMode = isDesktop ? .desktop : .mobile

        // Add user script for media state and fullscreen observation
        let userScript = WKUserScript(
            source: YouTubeHelper.mediaObserverScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(userScript)
        configuration.userContentController.add(context.coordinator, name: "mediaBridge")

        // Apply content blocking rules (ad & tracker filters)
        ContentBlockerManager.shared.apply(
            to: configuration.userContentController,
            enabled: viewModel.settingsManager.blockAdsAndTrackers
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.customUserAgent = isDesktop ? desktopUA : nil

        // Attach delegate
        context.coordinator.navigationDelegate.attach(to: webView)
        context.coordinator.navigationDelegate.observer = context.coordinator

        // Register webView with viewModel for the active tab
        viewModel.registerWebView(webView, for: tabId)

        // If target URL is already present, load it immediately upon creation
        if let tab = viewModel.tabManager.tabs.first(where: { $0.id == tabId }),
           let targetURL = tab.url,
           targetURL.absoluteString != "about:blank" {
            let request = URLRequest(url: targetURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            webView.load(request)
        }

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let isDesktop = viewModel.settingsManager.requestDesktopSites
        let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        uiView.customUserAgent = isDesktop ? desktopUA : nil

        // If tab URL is set and webView hasn't loaded it yet
        if let tab = viewModel.tabManager.tabs.first(where: { $0.id == tabId }),
           let targetURL = tab.url,
           targetURL.absoluteString != "about:blank" {
            if uiView.url == nil || uiView.url?.absoluteString == "about:blank" || uiView.url != targetURL {
                let request = URLRequest(url: targetURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
                uiView.load(request)
            }
        }
    }

    public static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "mediaBridge")
        coordinator.navigationDelegate.detach()
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, WebNavigationObserver, WKScriptMessageHandler {
        let parent: WebViewContainer
        let navigationDelegate: WebNavigationDelegate

        init(_ parent: WebViewContainer) {
            self.parent = parent
            self.navigationDelegate = WebNavigationDelegate()
            super.init()
        }

        // MARK: - WebNavigationObserver

        public func webViewDidStartLoading(_ webView: WKWebView) {
            parent.viewModel.handleDidStartLoading(for: parent.tabId)
        }

        public func webViewDidFinishLoading(_ webView: WKWebView, title: String?, url: URL?) {
            parent.viewModel.handleDidFinishLoading(for: parent.tabId, title: title, url: url)
        }

        public func webViewDidFailLoading(_ webView: WKWebView, error: Error) {
            parent.viewModel.handleDidFailLoading(for: parent.tabId, error: error)
        }

        public func webViewDidChangeProgress(_ progress: Double) {
            parent.viewModel.handleProgress(for: parent.tabId, progress: progress)
        }

        public func webViewDidChangeBackForwardState(canGoBack: Bool, canGoForward: Bool) {
            parent.viewModel.handleBackForwardState(for: parent.tabId, canGoBack: canGoBack, canGoForward: canGoForward)
        }

        public func webViewDidDetectMediaPlayback(title: String?, duration: Double?, isPlaying: Bool) {
            // Handled via mediaBridge script message handler
        }

        // MARK: - WKScriptMessageHandler

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "mediaBridge",
                  let body = message.body as? [String: Any] else { return }

            let messageType = body["type"] as? String ?? "state"

            if messageType == "fullscreen" {
                let isFullscreen = body["isFullscreen"] as? Bool ?? false
                DispatchQueue.main.async {
                    self.parent.viewModel.isFullscreenVideo = isFullscreen
                }
                return
            }

            guard let title = body["title"] as? String,
                  let duration = body["duration"] as? Double,
                  let currentTime = body["currentTime"] as? Double,
                  let isPlaying = body["isPlaying"] as? Bool else {
                return
            }

            parent.viewModel.handleMediaStateUpdate(
                title: title,
                duration: duration,
                currentTime: currentTime,
                isPlaying: isPlaying
            )
        }
    }
}
