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
                lower.contains("youtube.com/pagead/") ||
                lower.contains("youtube.com/api/stats/ads") ||
                lower.contains("youtube.com/api/stats/atr") ||
                lower.contains("youtube.com/ptracking") ||
                lower.contains("youtube.com/get_midroll_info") ||
                lower.contains("static.doubleclick.net") ||
                lower.contains("adservice.google.") ||
                lower.contains("googlesyndication.com")
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
     * 100% Ad Blocker & Instant Ad Auto-Skipper:
     * 1. Injects aggressive CSS to hide banners, overlays, promos, and sponsored slots.
     * 2. Auto-clicks skip buttons within milliseconds.
     * 3. If an unskippable video ad appears, mutes it, jumps to duration, and triggers skipAd.
     */
    const val AD_AND_PROMO_SUPPRESSION_SCRIPT = """
        (function() {
            try {
                // 1. Inject aggressive CSS
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
                        ytd-ad-slot-renderer, ytd-in-feed-ad-layout-renderer, .ytd-player-legacy-desktop-watch-ads-renderer {
                            display: none !important;
                        }
                    `;
                    (document.head || document.documentElement).appendChild(style);
                }

                // 2. High-speed Ad Skipper
                function skipAllAds() {
                    try {
                        // Click skip buttons
                        const skipSelectors = [
                            '.ytp-ad-skip-button',
                            '.ytp-ad-skip-button-modern',
                            '.ytp-skip-ad-button',
                            '.ytp-ad-skip-button-slot button',
                            '.videoAdUiSkipButton',
                            'button.ytp-ad-overlay-close-button',
                            'button[aria-label="Skip ad"]',
                            '.ytp-ad-skip-button-container button'
                        ];
                        for (let i = 0; i < skipSelectors.length; i++) {
                            const btn = document.querySelector(skipSelectors[i]);
                            if (btn) {
                                btn.click();
                            }
                        }

                        // Check if ad is interrupting / showing
                        const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                        const isAdPlaying = (player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'))) ||
                                            document.querySelector('.ad-showing') !== null ||
                                            document.querySelector('.ytp-ad-player-overlay') !== null;

                        if (isAdPlaying) {
                            const videos = document.querySelectorAll('video');
                            for (let i = 0; i < videos.length; i++) {
                                const v = videos[i];
                                if (v && !v.ended) {
                                    v.muted = true;
                                    v.playbackRate = 16.0;
                                    if (isFinite(v.duration) && v.duration > 0) {
                                        v.currentTime = v.duration;
                                    } else {
                                        v.currentTime = 99999;
                                    }
                                }
                            }
                            if (player && typeof player.skipAd === 'function') {
                                player.skipAd();
                            }
                        }
                    } catch(e) {}
                }

                skipAllAds();
                if (!window.__kiaAdBlockerRunning) {
                    window.__kiaAdBlockerRunning = true;
                    setInterval(skipAllAds, 200);

                    const observer = new MutationObserver(skipAllAds);
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
