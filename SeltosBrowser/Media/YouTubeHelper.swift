import Foundation

/// Helper for coordinating YouTube web interactions, HTML5 media observation, and playback scripts
public struct YouTubeHelper {

    /// Checks if a given URL belongs to YouTube
    public static func isYouTubeURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains("youtube.com") || host.contains("youtu.be")
    }

    /// User script injected into WKWebView to observe HTML5 <video> elements, fullscreen events, and relay state to Swift
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

        function notifyFullscreen(isFullscreen) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mediaBridge) {
                window.webkit.messageHandlers.mediaBridge.postMessage({
                    type: 'fullscreen',
                    isFullscreen: isFullscreen
                });
            }
        }

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
                if (Math.floor(video.currentTime) % 5 === 0) {
                    notifyState();
                }
            });
            video.addEventListener('ended', notifyState);

            // Native fullscreen events on iOS video element
            video.addEventListener('webkitbeginfullscreen', () => notifyFullscreen(true));
            video.addEventListener('webkitendfullscreen', () => notifyFullscreen(false));
        }

        // Global fullscreen change listeners
        document.addEventListener('fullscreenchange', () => {
            const isFs = !!(document.fullscreenElement || document.webkitFullscreenElement);
            notifyFullscreen(isFs);
        });
        document.addEventListener('webkitfullscreenchange', () => {
            const isFs = !!(document.fullscreenElement || document.webkitFullscreenElement);
            notifyFullscreen(isFs);
        });

        // Hook existing videos
        document.querySelectorAll('video').forEach(hookVideo);

        // Observe DOM for newly inserted videos
        const observer = new MutationObserver(mutations => {
            document.querySelectorAll('video').forEach(hookVideo);
        });
        if (document.body) {
            observer.observe(document.body, { childList: true, subtree: true });
        } else {
            document.addEventListener('DOMContentLoaded', () => {
                observer.observe(document.body, { childList: true, subtree: true });
                document.querySelectorAll('video').forEach(hookVideo);
            });
        }
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

    /// JavaScript to seek backward/forward relative to current position
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

    /// JavaScript to trigger native iOS fullscreen on the active video
    public static let enterFullscreenScript = """
    (function() {
        const video = document.querySelector('video');
        if (video) {
            if (video.webkitEnterFullscreen) {
                video.webkitEnterFullscreen();
            } else if (video.requestFullscreen) {
                video.requestFullscreen();
            }
        }
    })();
    """

    /// JavaScript for Reader Mode
    public static let enableReaderModeScript = """
    (function() {
        if (document.getElementById('kia-reader-mode-style')) return;
        const style = document.createElement('style');
        style.id = 'kia-reader-mode-style';
        style.textContent = `
            body {
                max-width: 700px !important;
                margin: 0 auto !important;
                padding: 24px 20px 80px !important;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif !important;
                font-size: 19px !important;
                line-height: 1.75 !important;
                color: #1c1c1e !important;
                background-color: #fbfbfd !important;
            }
            @media (prefers-color-scheme: dark) {
                body {
                    color: #f2f2f7 !important;
                    background-color: #141416 !important;
                }
            }
            nav, header, footer, aside, .ad, .ads, .sidebar, .popup, .banner, iframe, [role="banner"], [role="navigation"] {
                display: none !important;
            }
            img {
                max-width: 100% !important;
                height: auto !important;
                border-radius: 10px !important;
                margin: 20px 0 !important;
            }
            h1, h2, h3, h4 {
                line-height: 1.3 !important;
                margin-top: 1.2em !important;
                margin-bottom: 0.6em !important;
            }
            p {
                margin-bottom: 1.2em !important;
            }
        `;
        document.head.appendChild(style);
    })();
    """

    /// JavaScript to disable Reader Mode
    public static let disableReaderModeScript = """
    (function() {
        const el = document.getElementById('kia-reader-mode-style');
        if (el) el.remove();
    })();
    """
}
