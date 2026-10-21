import Foundation
import WebKit

/// Protocol to relay WKWebView navigation and status events to the BrowserViewModel
public protocol WebNavigationObserver: AnyObject {
    func webViewDidStartLoading(_ webView: WKWebView)
    func webViewDidFinishLoading(_ webView: WKWebView, title: String?, url: URL?)
    func webViewDidFailLoading(_ webView: WKWebView, error: Error)
    func webViewDidChangeProgress(_ progress: Double)
    func webViewDidChangeBackForwardState(canGoBack: Bool, canGoForward: Bool)
    func webViewDidDetectMediaPlayback(title: String?, duration: Double?, isPlaying: Bool)
}

/// Navigation and UI delegate for WKWebView enforcing security and tracking progress
public final class WebNavigationDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    public weak var observer: WebNavigationObserver?
    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?

    public init(observer: WebNavigationObserver? = nil) {
        self.observer = observer
        super.init()
    }

    public func attach(to webView: WKWebView) {
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Observe estimated progress
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            self?.observer?.webViewDidChangeProgress(wv.estimatedProgress)
        }

        // Observe title changes
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            self?.observer?.webViewDidFinishLoading(wv, title: wv.title, url: wv.url)
        }

        // Observe URL changes
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            self?.observer?.webViewDidChangeBackForwardState(
                canGoBack: wv.canGoBack,
                canGoForward: wv.canGoForward
            )
        }
    }

    public func detach() {
        progressObservation?.invalidate()
        titleObservation?.invalidate()
        urlObservation?.invalidate()
        progressObservation = nil
        titleObservation = nil
        urlObservation = nil
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // Block external application deep links (prevents opening native YouTube / App Store apps)
        if scheme == "youtube" || scheme == "vnd.youtube" || scheme == "intent" || scheme == "itms-appss" {
            decisionHandler(.cancel)
            return
        }

        // Intercept link clicks to prevent iOS Universal Links from handing off to external apps
        if navigationAction.navigationType == .linkActivated,
           let host = url.host?.lowercased(),
           host.contains("youtube.com") || host.contains("youtu.be") {
            // Cancel system universal link handoff and load strictly inside this WKWebView
            decisionHandler(.cancel)
            webView.load(URLRequest(url: url))
            return
        }

        if WebKitSecurityPolicy.isNavigationAllowed(for: url) {
            decisionHandler(.allow)
        } else {
            // Cancel unauthorized schemes
            decisionHandler(.cancel)
        }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        observer?.webViewDidStartLoading(webView)
        observer?.webViewDidChangeBackForwardState(
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        observer?.webViewDidFinishLoading(webView, title: webView.title, url: webView.url)
        observer?.webViewDidChangeBackForwardState(
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        // Ignore NSURLErrorCancelled (code -999) caused by intentional redirects or user interruptions
        if nsError.code != NSURLErrorCancelled {
            observer?.webViewDidFailLoading(webView, error: error)
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code != NSURLErrorCancelled {
            observer?.webViewDidFailLoading(webView, error: error)
        }
    }

    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Enforce standard system trust validation; reject self-signed or invalid certs
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // MARK: - WKUIDelegate

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Open target="_blank" links in the same webView
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
