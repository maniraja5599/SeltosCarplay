import SwiftUI
import WebKit

/// SwiftUI wrapper around WKWebView configured for full media, inline playback, and security
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

        if #available(iOS 15.4, *) {
            configuration.preferences.isElementFullscreenEnabled = true
        }

        // Add user script for media state observation
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

        // Attach delegate
        context.coordinator.navigationDelegate.attach(to: webView)
        context.coordinator.navigationDelegate.observer = context.coordinator

        // Register webView with viewModel for the active tab
        viewModel.registerWebView(webView, for: tabId)

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // Adjust custom user agent if desktop site mode changes
        let isDesktop = viewModel.settingsManager.requestDesktopSites
        let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        uiView.customUserAgent = isDesktop ? desktopUA : nil

        // If tab URL is set and webView hasn't loaded it yet
        if let tab = viewModel.tabManager.tabs.first(where: { $0.id == tabId }),
           let targetURL = tab.url,
           uiView.url != targetURL && !tab.isLoading && uiView.url == nil {
            let request = URLRequest(url: targetURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            uiView.load(request)
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
            // Handled via script message handler
        }

        // MARK: - WKScriptMessageHandler

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "mediaBridge",
                  let body = message.body as? [String: Any],
                  let title = body["title"] as? String,
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
