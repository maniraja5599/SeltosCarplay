package com.seltos.kiabrowser

object YouTubeWebHelper {

    fun isYouTubeUrl(url: String?): Boolean {
        if (url == null) return false
        val lower = url.lowercase()
        return lower.contains("youtube.com") || lower.contains("youtu.be")
    }

    /**
     * Injected into WebView so YouTube and video sites NEVER pause when screen turns off or switches app
     */
    const val ANTI_BACKGROUND_PAUSE_SCRIPT = """
        (function() {
            try {
                Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
                Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
                Object.defineProperty(document, 'webkitVisibilityState', { get: () => 'visible', configurable: true });
                Object.defineProperty(document, 'webkitHidden', { get: () => false, configurable: true });

                document.addEventListener('visibilitychange', function(e) {
                    e.stopImmediatePropagation();
                }, true);
            } catch(e) {}
        })();
    """

    /**
     * Suppresses mobile YouTube install popups, open-in-app banners, and floating banners
     */
    const val AD_AND_PROMO_SUPPRESSION_SCRIPT = """
        (function() {
            try {
                const style = document.createElement('style');
                style.textContent = `
                    ytm-pivot-bar-renderer, .upsell-dialog, .mobile-topbar-header-upsell,
                    ytm-app-banner, .open-in-app, .standalone-collection-badge-renderer,
                    .ad-showing, .video-ads, .ytp-ad-module { display: none !important; }
                `;
                document.documentElement.appendChild(style);
            } catch(e) {}
        })();
    """

    /**
     * Seek relative delta in seconds (+5 or -5)
     * Handles both YouTube Player API (movie_player) and HTML5 video
     */
    fun seekScript(deltaSeconds: Int): String {
        return """
            (function() {
                const delta = $deltaSeconds;
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
        """.trimIndent()
    }

    /**
     * Seek to absolute timestamp in seconds
     */
    fun seekToScript(positionSeconds: Double): String {
        return """
            (function() {
                const pos = $positionSeconds;
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
        """.trimIndent()
    }

    /**
     * Toggle Play/Pause
     */
    const val TOGGLE_PLAY_PAUSE_SCRIPT = """
        (function() {
            const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
            if (player && typeof player.getPlayerState === 'function') {
                const state = player.getPlayerState();
                if (state === 1) { // playing
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
}
