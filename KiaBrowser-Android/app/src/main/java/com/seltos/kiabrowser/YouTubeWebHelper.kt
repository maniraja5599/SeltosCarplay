package com.seltos.kiabrowser

object YouTubeWebHelper {

    fun isYouTubeUrl(url: String?): Boolean {
        if (url == null) return false
        val lower = url.lowercase()
        return lower.contains("youtube.com") || lower.contains("youtu.be")
    }

    /**
     * Checks if a network request URL is an ad network or tracking endpoint
     */
    fun isAdUrl(url: String?): Boolean {
        if (url == null) return false
        val lower = url.lowercase()
        return lower.contains("googleads.g.doubleclick.net") ||
                lower.contains("pubads.g.doubleclick.net") ||
                lower.contains("pagead2.googlesyndication.com") ||
                lower.contains("static.doubleclick.net") ||
                lower.contains("adservice.google.") ||
                lower.contains("googlesyndication.com") ||
                lower.contains("doubleclick.net")
    }

    /**
     * Injected into WebView so YouTube and video sites NEVER pause when screen turns off or switches app.
     * Spoofs Page Visibility API and cancels visibility change events cleanly without freezing media elements.
     */
    const val ANTI_BACKGROUND_PAUSE_SCRIPT = """
        (function() {
            try {
                // 1. Spoof Page Visibility API
                Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
                Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
                Object.defineProperty(document, 'webkitVisibilityState', { get: () => 'visible', configurable: true });
                Object.defineProperty(document, 'webkitHidden', { get: () => false, configurable: true });

                // 2. Suppress visibilitychange, blur and pagehide events
                const suppress = e => {
                    e.stopImmediatePropagation();
                };
                window.addEventListener('visibilitychange', suppress, true);
                document.addEventListener('visibilitychange', suppress, true);
                window.addEventListener('webkitvisibilitychange', suppress, true);
                document.addEventListener('webkitvisibilitychange', suppress, true);
                window.addEventListener('blur', suppress, true);
                window.addEventListener('pagehide', suppress, true);
            } catch(e) {}
        })();
    """

    /**
     * 100% Comprehensive YouTube & Web Ad Blocker:
     * 1. Intercepts ytInitialPlayerResponse & /youtubei/v1/player API responses to strip all adPlacements,
     *    giving a clean YouTube Premium experience where ads are never even scheduled.
     * 2. High-frequency DOM Ad Skipper & Fast-Forwarder on timeupdate and 50ms interval.
     * 3. Aggressive CSS suppression of all banner, overlay, and promoted ad components.
     */
    const val AD_AND_PROMO_SUPPRESSION_SCRIPT = """
        (function() {
            try {
                // Helper to remove all ad data structures from YouTube player JSON responses
                function sanitizePlayerJson(data) {
                    if (!data || typeof data !== 'object') return data;
                    try {
                        if (data.adPlacements) delete data.adPlacements;
                        if (data.playerAds) delete data.playerAds;
                        if (data.adSlots) delete data.adSlots;
                        if (data.adBreakHeartbeatParams) delete data.adBreakHeartbeatParams;
                        if (data.playbackTracking) {
                            delete data.playbackTracking.videostatsPlaybackUrl;
                            delete data.playbackTracking.videostatsDelayplayUrl;
                            delete data.playbackTracking.videostatsWatchtimeUrl;
                            delete data.playbackTracking.qoeUrl;
                            delete data.playbackTracking.atrUrl;
                        }
                    } catch(e) {}
                    return data;
                }

                // 1. Intercept initial player response before YouTube player boots
                if (window.ytInitialPlayerResponse) {
                    sanitizePlayerJson(window.ytInitialPlayerResponse);
                }
                let _storedPlayerResponse = window.ytInitialPlayerResponse;
                try {
                    Object.defineProperty(window, 'ytInitialPlayerResponse', {
                        get: () => _storedPlayerResponse,
                        set: (val) => { _storedPlayerResponse = sanitizePlayerJson(val); },
                        configurable: true
                    });
                } catch(e) {}

                // 2. Intercept window.fetch for /youtubei/v1/player requests
                if (!window.__kiaFetchPatched) {
                    window.__kiaFetchPatched = true;
                    const origFetch = window.fetch;
                    window.fetch = async function(...args) {
                        const response = await origFetch.apply(this, args);
                        try {
                            const url = typeof args[0] === 'string' ? args[0] : (args[0] && args[0].url ? args[0].url : '');
                            if (url && (url.includes('/youtubei/v1/player') || url.includes('/youtubei/v1/next'))) {
                                const clone = response.clone();
                                const json = await clone.json();
                                if (json) {
                                    sanitizePlayerJson(json);
                                    return new Response(JSON.stringify(json), {
                                        status: response.status,
                                        statusText: response.statusText,
                                        headers: response.headers
                                    });
                                }
                            }
                        } catch(e) {}
                        return response;
                    };
                }

                // 3. Intercept XMLHttpRequest for /youtubei/v1/player requests
                if (!window.__kiaXhrPatched) {
                    window.__kiaXhrPatched = true;
                    const origXhrOpen = XMLHttpRequest.prototype.open;
                    const origXhrSend = XMLHttpRequest.prototype.send;
                    XMLHttpRequest.prototype.open = function(method, url) {
                        this._kiaRequestUrl = url;
                        return origXhrOpen.apply(this, arguments);
                    };
                    XMLHttpRequest.prototype.send = function() {
                        if (this._kiaRequestUrl && (this._kiaRequestUrl.includes('/youtubei/v1/player') || this._kiaRequestUrl.includes('/youtubei/v1/next'))) {
                            this.addEventListener('readystatechange', function() {
                                if (this.readyState === 4 && this.status === 200) {
                                    try {
                                        const json = JSON.parse(this.responseText);
                                        sanitizePlayerJson(json);
                                        Object.defineProperty(this, 'responseText', { value: JSON.stringify(json), writable: true });
                                        Object.defineProperty(this, 'response', { value: JSON.stringify(json), writable: true });
                                    } catch(e) {}
                                }
                            });
                        }
                        return origXhrSend.apply(this, arguments);
                    };
                }

                // 4. Inject Aggressive CSS to hide all ad elements
                if (!document.getElementById('kia-adblock-style')) {
                    const style = document.createElement('style');
                    style.id = 'kia-adblock-style';
                    style.textContent = `
                        .ad-showing, .ad-interrupting, .video-ads, .ytp-ad-module, .ytp-ad-overlay-container,
                        .ytp-ad-overlay-slot, .ytp-ad-message-container, .ytp-ad-image-overlay,
                        ytm-promoted-sparkles-web-renderer, ytd-promoted-video-renderer, ytd-display-ad-renderer,
                        ytd-statement-banner-renderer, ytd-in-feed-ad-layout-renderer, ytd-banner-promo-renderer,
                        .ad-container, #player-ads, .ytp-ad-progress-list, ytm-promoted-sparkles-text-search-web-renderer,
                        ytm-pivot-bar-renderer, .upsell-dialog, .mobile-topbar-header-upsell, ytm-app-banner,
                        .open-in-app, .standalone-collection-badge-renderer, #masthead-ad,
                        ytd-rich-item-renderer:has(.ytd-ad-slot-renderer),
                        ytd-ad-slot-renderer, ytd-in-feed-ad-layout-renderer, .ytd-player-legacy-desktop-watch-ads-renderer,
                        ytm-companion-ad-renderer, ytm-promoted-item-renderer, ytm-ad-slot-renderer,
                        .ytp-ad-player-overlay, .ytp-ad-text {
                            display: none !important;
                        }
                    `;
                    (document.head || document.documentElement).appendChild(style);
                }

                // 5. Ultra-Fast Ad Auto-Skipper & Fast-Forwarder
                function eliminateActiveAds() {
                    try {
                        // A. Click all skip buttons
                        const skipButtons = document.querySelectorAll(
                            '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, ' +
                            '.ytp-ad-skip-button-slot button, .videoAdUiSkipButton, ' +
                            'button.ytp-ad-overlay-close-button, button[aria-label*="Skip"], ' +
                            '.ytm-skip-ad-button, .ytp-ad-preview-container, .ytp-ad-skip-button-container button, ' +
                            'button[class*="skip"], div[class*="skip-button"]'
                        );
                        for (let i = 0; i < skipButtons.length; i++) {
                            const btn = skipButtons[i];
                            if (btn && typeof btn.click === 'function') {
                                btn.click();
                            }
                        }

                        // B. Check if ad is active
                        const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                        const adShowing = document.querySelector('.ad-showing') !== null ||
                                          document.querySelector('.ad-interrupting') !== null ||
                                          document.querySelector('.ytp-ad-player-overlay') !== null ||
                                          document.querySelector('.ytp-ad-text') !== null ||
                                          (player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting')));

                        if (adShowing) {
                            const videos = document.querySelectorAll('video');
                            for (let i = 0; i < videos.length; i++) {
                                const v = videos[i];
                                if (v && !v.ended) {
                                    v.muted = true;
                                    v.playbackRate = 16.0;
                                    if (isFinite(v.duration) && v.duration > 0) {
                                        v.currentTime = v.duration;
                                    }
                                }
                            }
                            if (player && typeof player.skipAd === 'function') {
                                player.skipAd();
                            }
                        }
                    } catch(e) {}
                }

                // Trigger on timeupdate & high-speed interval
                eliminateActiveAds();
                document.addEventListener('timeupdate', eliminateActiveAds, true);
                document.addEventListener('playing', eliminateActiveAds, true);

                if (!window.__kiaAdBlockerLoop) {
                    window.__kiaAdBlockerLoop = true;
                    setInterval(eliminateActiveAds, 50);

                    const observer = new MutationObserver(eliminateActiveAds);
                    observer.observe(document.documentElement || document.body, {
                        childList: true,
                        subtree: true
                    });
                }
            } catch(e) {}
        })();
    """

    /**
     * Seek relative delta in seconds (+5 or -5)
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

    /**
     * Next Video Track
     */
    const val NEXT_TRACK_SCRIPT = """
        (function() {
            try {
                const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.nextVideo === 'function') {
                    player.nextVideo();
                    return;
                }
                const nextBtn = document.querySelector('.ytp-next-button') ||
                                document.querySelector('a.ytp-next-button') ||
                                document.querySelector('[aria-label="Next"]');
                if (nextBtn) {
                    nextBtn.click();
                }
            } catch(e) {}
        })();
    """

    /**
     * Previous Video Track
     */
    const val PREV_TRACK_SCRIPT = """
        (function() {
            try {
                const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                if (player && typeof player.previousVideo === 'function') {
                    player.previousVideo();
                    return;
                }
                const prevBtn = document.querySelector('.ytp-prev-button') ||
                                document.querySelector('a.ytp-prev-button') ||
                                document.querySelector('[aria-label="Previous"]');
                if (prevBtn) {
                    prevBtn.click();
                    return;
                }
                // Fallback: Restart current video
                if (player && typeof player.seekTo === 'function') {
                    player.seekTo(0, true);
                } else {
                    const v = document.querySelector('video');
                    if (v) v.currentTime = 0;
                }
            } catch(e) {}
        })();
    """
}
