import Foundation

/// Helper for coordinating YouTube web interactions, HTML5 media observation, background playback, and seek scripts
public struct YouTubeHelper {

    /// Checks if a given URL belongs to YouTube
    public static func isYouTubeURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains("youtube.com") || host.contains("youtu.be")
    }

    /// Script injected at document start to trick YouTube/media sites into thinking the page is ALWAYS active and visible
    public static let antiBackgroundPauseScript = """
    (function() {
        try {
            Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
            Object.defineProperty(document, 'webkitVisibilityState', { get: () => 'visible', configurable: true });
            Object.defineProperty(document, 'webkitHidden', { get: () => false, configurable: true });

            document.addEventListener('visibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
            document.addEventListener('webkitvisibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
        } catch(e) {}
    })();
    """

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
                if (Math.floor(video.currentTime) % 2 === 0) {
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

    /// JavaScript to toggle play/pause on YouTube player or first active video element
    public static let togglePlayPauseScript = """
    (function() {
        const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
        if (player && typeof player.getPlayerState === 'function') {
            const state = player.getPlayerState();
            if (state === 1) { // 1 = playing
                player.pauseVideo();
            } else {
                player.playVideo();
            }
            return;
        }

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
        const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
        if (player && typeof player.playVideo === 'function') {
            player.playVideo();
            return;
        }
        const video = document.querySelector('video');
        if (video && video.paused) {
            video.play();
        }
    })();
    """

    /// JavaScript to force pause
    public static let pauseScript = """
    (function() {
        const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
        if (player && typeof player.pauseVideo === 'function') {
            player.pauseVideo();
            return;
        }
        const video = document.querySelector('video');
        if (video && !video.paused) {
            video.pause();
        }
    })();
    """

    /// JavaScript to seek backward/forward relative to current position (works with YouTube Player API & standard HTML5 video)
    public static func seekScript(delta: Double) -> String {
        return """
        (function() {
            const delta = \(delta);
            const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
            if (player && typeof player.seekBy === 'function') {
                player.seekBy(delta);
                return;
            }
            if (player && typeof player.getCurrentTime === 'function' && typeof player.seekTo === 'function') {
                const current = player.getCurrentTime() || 0;
                player.seekTo(Math.max(0, current + delta), true);
                return;
            }

            const video = document.querySelector('video');
            if (video) {
                video.currentTime = Math.max(0, Math.min(video.duration || 0, video.currentTime + delta));
            }
        })();
        """
    }

    /// JavaScript to seek to an absolute timestamp in seconds (for CarPlay scrubber bar)
    public static func seekToScript(position: Double) -> String {
        return """
        (function() {
            const pos = \(position);
            const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
            if (player && typeof player.seekTo === 'function') {
                player.seekTo(pos, true);
                return;
            }
            const video = document.querySelector('video');
            if (video) {
                video.currentTime = Math.max(0, Math.min(video.duration || 0, pos));
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
