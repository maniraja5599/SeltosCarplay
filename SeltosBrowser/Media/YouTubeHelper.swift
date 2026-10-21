import Foundation

/// Helper for coordinating YouTube web interactions, HTML5 media observation, and playback scripts
public struct YouTubeHelper {

    /// Checks if a given URL belongs to YouTube
    public static func isYouTubeURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains("youtube.com") || host.contains("youtu.be")
    }

    /// User script injected into WKWebView to observe HTML5 <video> elements and relay state to Swift
    public static let mediaObserverScript = """
    (function() {
        if (window.__seltosMediaObserverLoaded) return;
        window.__seltosMediaObserverLoaded = true;

        // Suppress mobile YouTube app install popups and top banners
        try {
            const bannerStyle = document.createElement('style');
            bannerStyle.textContent = 'ytm-pivot-bar-renderer, .upsell-dialog, .mobile-topbar-header-upsell, ytm-app-banner, .open-in-app, .standalone-collection-badge-renderer { display: none !important; }';
            document.documentElement.appendChild(bannerStyle);
        } catch (e) {}

        function hookVideo(video) {
            if (video.__hooked) return;
            video.__hooked = true;

            const notifyState = () => {
                const title = document.title || 'Web Video';
                const duration = video.duration || 0;
                const currentTime = video.currentTime || 0;
                const isPlaying = !video.paused && !video.ended && video.readyState > 2;

                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mediaBridge) {
                    window.webkit.messageHandlers.mediaBridge.postMessage({
                        type: 'state',
                        title: title,
                        duration: duration,
                        currentTime: currentTime,
                        isPlaying: isPlaying
                    });
                }
            };

            video.addEventListener('play', notifyState);
            video.addEventListener('playing', notifyState);
            video.addEventListener('pause', notifyState);
            video.addEventListener('timeupdate', () => {
                // Throttle updates
                if (Math.floor(video.currentTime) % 5 === 0) {
                    notifyState();
                }
            });
            video.addEventListener('ended', notifyState);
        }

        // Hook existing videos
        document.querySelectorAll('video').forEach(hookVideo);

        // Observe DOM for newly inserted videos
        const observer = new MutationObserver(mutations => {
            document.querySelectorAll('video').forEach(hookVideo);
        });
        observer.observe(document.body, { childList: true, subtree: true });
    })();
    """

    /// JavaScript to toggle play/pause on the first active video element
    public static let togglePlayPauseScript = """
    (function() {
        const video = document.querySelector('video');
        if (video) {
            if (video.paused) {
                video.play();
            } else {
                video.pause();
            }
        }
    })();
    """

    /// JavaScript to force play
    public static let playScript = """
    (function() {
        const video = document.querySelector('video');
        if (video && video.paused) {
            video.play();
        }
    })();
    """

    /// JavaScript to force pause
    public static let pauseScript = """
    (function() {
        const video = document.querySelector('video');
        if (video && !video.paused) {
            video.pause();
        }
    })();
    """

    /// JavaScript to seek relative seconds
    public static func seekScript(delta: Double) -> String {
        return """
        (function() {
            const video = document.querySelector('video');
            if (video) {
                video.currentTime = Math.max(0, Math.min(video.duration || 0, video.currentTime + (\(delta))));
            }
        })();
        """
    }
}
