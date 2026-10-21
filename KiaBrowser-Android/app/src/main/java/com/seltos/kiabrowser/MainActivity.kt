package com.seltos.kiabrowser

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.speech.RecognizerIntent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.webkit.*
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import com.seltos.kiabrowser.databinding.ActivityMainBinding
import java.util.Locale

class MainActivity : AppCompatActivity(), MediaControlListener, KiaPlaybackService.PlaybackCallback {

    private lateinit var binding: ActivityMainBinding
    private lateinit var settingsManager: SettingsManager
    private lateinit var mediaSessionManager: KiaMediaSessionManager
    private lateinit var carDisplayManager: KiaCarDisplayManager

    private var isHome = true
    private var lastMediaTitle = "Kia Browser"
    private var isPlayingMedia = false
    private var isFullscreen = false
    private var lastLoadedUrl: String? = null

    private val speechRecognizerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val spokenText: String? =
                result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.let { results ->
                    results.firstOrNull()
                }
            if (!spokenText.isNullOrBlank()) {
                binding.etSearchOrUrl.setText(spokenText)
                performSearch(spokenText)
            }
        }
    }

    private val requestNotificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { _ -> }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        settingsManager = SettingsManager.getInstance(this)
        mediaSessionManager = KiaMediaSessionManager(this, this)
        KiaPlaybackService.activeCallback = this

        checkNotificationPermission()

        carDisplayManager = KiaCarDisplayManager(this) { isAttached, _ ->
            runOnUiThread {
                if (isAttached) {
                    binding.tvCarStatusTitle.text = "Kia Seltos Screen Connected"
                    binding.tvCarStatusSubtitle.text = "Video & Controls streaming to car display"
                } else {
                    binding.tvCarStatusTitle.text = "Car Display Ready"
                    binding.tvCarStatusSubtitle.text = "Plug into car USB / Wireless Android Auto"
                }
            }
        }

        setupWebView()
        setupListeners()
        setupShortcuts()
        setupHomeSettings()
        updateSeekButtonLabels()

        val initialUrl = intent?.dataString
        if (!initialUrl.isNullOrBlank()) {
            loadUrl(initialUrl)
        } else {
            showHome()
        }

        carDisplayManager.startListening()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent?.dataString?.let { url ->
            loadUrl(url)
        }
    }

    private fun checkNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                requestNotificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        binding.mainWebView.resumeTimers()
    }

    override fun onPause() {
        super.onPause()
        // Do NOT call binding.mainWebView.onPause() so background video/audio keeps playing!
        binding.mainWebView.resumeTimers()
    }

    override fun onDestroy() {
        super.onDestroy()
        KiaPlaybackService.activeCallback = null
        carDisplayManager.stopListening()
        mediaSessionManager.release()
    }

    private fun updateSeekButtonLabels() {
        val step = settingsManager.seekInterval
        val textBack = "-${step}s"
        val textForward = "+${step}s"
        binding.btnNavRewind5.text = textBack
        binding.btnNavForward5.text = textForward
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        val webSettings = binding.mainWebView.settings
        webSettings.javaScriptEnabled = true
        webSettings.domStorageEnabled = true
        webSettings.mediaPlaybackRequiresUserGesture = false
        webSettings.allowFileAccess = true
        webSettings.loadWithOverviewMode = true
        webSettings.useWideViewPort = true
        webSettings.databaseEnabled = true

        applyDesktopMode(settingsManager.isDesktopMode)

        // Inject anti-pause and ad-block scripts at document start before YouTube page scripts execute
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(
                binding.mainWebView,
                YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT,
                setOf("*")
            )
            WebViewCompat.addDocumentStartJavaScript(
                binding.mainWebView,
                YouTubeWebHelper.AD_AND_PROMO_SUPPRESSION_SCRIPT,
                setOf("*")
            )
        }

        binding.mainWebView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?
            ): WebResourceResponse? {
                val url = request?.url?.toString()
                if (settingsManager.isAdBlockEnabled && YouTubeWebHelper.isAdUrl(url)) {
                    return WebResourceResponse(
                        "text/plain",
                        "UTF-8",
                        java.io.ByteArrayInputStream(ByteArray(0))
                    )
                }
                return super.shouldInterceptRequest(view, request)
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                binding.loadingProgress.visibility = View.VISIBLE
                binding.mainWebView.evaluateJavascript(YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT, null)
                if (settingsManager.isAdBlockEnabled) {
                    binding.mainWebView.evaluateJavascript(YouTubeWebHelper.AD_AND_PROMO_SUPPRESSION_SCRIPT, null)
                }
            }

            override fun onLoadResource(view: WebView?, url: String?) {
                super.onLoadResource(view, url)
                if (settingsManager.isAdBlockEnabled && YouTubeWebHelper.isYouTubeUrl(view?.url)) {
                    view?.evaluateJavascript(YouTubeWebHelper.AD_AND_PROMO_SUPPRESSION_SCRIPT, null)
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                binding.loadingProgress.visibility = View.GONE
                binding.etSearchOrUrl.setText(url)
                binding.mainWebView.evaluateJavascript(YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT, null)
                if (settingsManager.isAdBlockEnabled) {
                    binding.mainWebView.evaluateJavascript(YouTubeWebHelper.AD_AND_PROMO_SUPPRESSION_SCRIPT, null)
                }

                val title = view?.title ?: "Kia Browser"
                lastMediaTitle = title
                isPlayingMedia = true
                updatePlayPauseButtonUi(true)
                mediaSessionManager.updateMetadata(title, "Kia Browser", 0)
                mediaSessionManager.updatePlaybackState(true, 0)

                // Bring playback controls to the front of scroll view
                if (!isHome) {
                    binding.mediaControlsGroup.post { binding.mediaControlsGroup.scrollTo(0, 0) }
                }

                // Start Foreground Service so Android never kills background playback
                KiaPlaybackService.startService(this@MainActivity, title, true)
            }
        }

        binding.mainWebView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                binding.loadingProgress.progress = newProgress
                if (newProgress >= 100) {
                    binding.loadingProgress.visibility = View.GONE
                }
            }

            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                consoleMessage?.message()?.let { msg ->
                    android.util.Log.d("KiaWebConsole", msg)
                }
                return true
            }
        }
    }

    private fun setupListeners() {
        // Search Input 'Go' on keyboard
        binding.etSearchOrUrl.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_GO || actionId == EditorInfo.IME_ACTION_DONE) {
                val query = binding.etSearchOrUrl.text.toString().trim()
                if (query.isNotEmpty()) {
                    performSearch(query)
                }
                true
            } else {
                false
            }
        }

        // Google Voice Search
        binding.btnVoiceSearch.setOnClickListener {
            startVoiceSearch()
        }

        // Reload
        binding.btnReload.setOnClickListener {
            if (isHome) {
                showHome()
            } else {
                binding.mainWebView.reload()
                carDisplayManager.currentPresentation?.togglePlayPause()
            }
        }

        // Play / Pause Toggle
        binding.btnNavPlayPause.setOnClickListener {
            if (isPlayingMedia) {
                onMediaPause()
            } else {
                onMediaPlay()
            }
        }

        // Previous Video Track
        binding.btnNavPrevious.setOnClickListener {
            onMediaPrevious()
        }

        // Next Video Track
        binding.btnNavNext.setOnClickListener {
            onMediaNext()
        }

        // Reload
        binding.btnNavReload.setOnClickListener {
            if (isHome) {
                showHome()
            } else {
                binding.mainWebView.reload()
            }
        }

        // Bottom Navigation
        binding.btnNavBack.setOnClickListener {
            if (binding.mainWebView.canGoBack() && !isHome) {
                binding.mainWebView.goBack()
            } else {
                showHome()
            }
        }

        binding.btnNavForward.setOnClickListener {
            if (binding.mainWebView.canGoForward() && !isHome) {
                binding.mainWebView.goForward()
            }
        }

        binding.btnNavHome.setOnClickListener {
            showHome()
        }

        // Seek Buttons (Default 5s, configurable)
        binding.btnNavRewind5.setOnClickListener {
            val step = settingsManager.seekInterval
            onMediaSeekBackward(step)
        }

        binding.btnNavForward5.setOnClickListener {
            val step = settingsManager.seekInterval
            onMediaSeekForward(step)
        }

        // Desktop Mode Toggle
        binding.btnToggleDesktop.setOnClickListener {
            val newMode = !settingsManager.isDesktopMode
            settingsManager.isDesktopMode = newMode
            applyDesktopMode(newMode)
            updateDesktopUi(newMode)
            binding.switchDesktop.isChecked = newMode
            Toast.makeText(this, if (newMode) "Desktop Site Enabled" else "Mobile Site Enabled", Toast.LENGTH_SHORT).show()
            if (!isHome) {
                binding.mainWebView.reload()
            }
        }

        // AdBlock Toggle
        binding.btnToggleAdBlock.setOnClickListener {
            val newMode = !settingsManager.isAdBlockEnabled
            settingsManager.isAdBlockEnabled = newMode
            updateAdBlockUi(newMode)
            binding.switchAdBlock.isChecked = newMode
            Toast.makeText(this, if (newMode) "Ad Blocker: ENABLED (All Ads Blocked)" else "Ad Blocker: DISABLED", Toast.LENGTH_SHORT).show()
            if (!isHome) {
                binding.mainWebView.reload()
            }
        }

        // Fullscreen Toggle
        binding.btnToggleFullscreen.setOnClickListener {
            isFullscreen = !isFullscreen
            binding.topBar.visibility = if (isFullscreen) View.GONE else View.VISIBLE
            binding.btnToggleFullscreen.setImageResource(
                if (isFullscreen) R.drawable.ic_fullscreen_exit else R.drawable.ic_fullscreen
            )
        }
    }

    private fun setupShortcuts() {
        binding.cardYouTube.setOnClickListener { loadUrl("https://m.youtube.com") }
        binding.cardHotstar.setOnClickListener { loadUrl("https://www.hotstar.com/in") }
        binding.cardNetflix.setOnClickListener { loadUrl("https://www.netflix.com") }
        binding.cardJioCinema.setOnClickListener { loadUrl("https://www.jiocinema.com") }
        binding.cardZee5.setOnClickListener { loadUrl("https://www.zee5.com") }
        binding.cardSpotify.setOnClickListener { loadUrl("https://open.spotify.com") }
        binding.cardCricbuzz.setOnClickListener { loadUrl("https://m.cricbuzz.com") }
        binding.cardMaps.setOnClickListener { loadUrl("https://maps.google.com") }
        binding.cardFast.setOnClickListener { loadUrl("https://fast.com") }
    }

    private fun setupHomeSettings() {
        val currentStep = settingsManager.seekInterval
        binding.tvCurrentSeekStep.text = "${currentStep}s"
        highlightSeekButton(currentStep)

        binding.btnSeek5s.setOnClickListener { setSeekInterval(5) }
        binding.btnSeek10s.setOnClickListener { setSeekInterval(10) }
        binding.btnSeek15s.setOnClickListener { setSeekInterval(15) }
        binding.btnSeek30s.setOnClickListener { setSeekInterval(30) }

        // AdBlock Switch
        binding.switchAdBlock.isChecked = settingsManager.isAdBlockEnabled
        updateAdBlockUi(settingsManager.isAdBlockEnabled)
        binding.switchAdBlock.setOnCheckedChangeListener { _, isChecked ->
            settingsManager.isAdBlockEnabled = isChecked
            updateAdBlockUi(isChecked)
            Toast.makeText(
                this,
                if (isChecked) "Ad Blocker Enabled (100% Ad-Free)" else "Ad Blocker Disabled",
                Toast.LENGTH_SHORT
            ).show()
        }

        // Desktop Mode Switch
        binding.switchDesktop.isChecked = settingsManager.isDesktopMode
        updateDesktopUi(settingsManager.isDesktopMode)
        binding.switchDesktop.setOnCheckedChangeListener { _, isChecked ->
            settingsManager.isDesktopMode = isChecked
            applyDesktopMode(isChecked)
            updateDesktopUi(isChecked)
            Toast.makeText(
                this,
                if (isChecked) "Desktop Browser Enabled" else "Mobile Browser Enabled",
                Toast.LENGTH_SHORT
            ).show()
        }

        // Clear Cache
        val clearCacheAction = {
            binding.mainWebView.clearCache(true)
            binding.mainWebView.clearHistory()
            android.webkit.CookieManager.getInstance().removeAllCookies(null)
            android.webkit.WebStorage.getInstance().deleteAllData()
            Toast.makeText(this, "Browser Cache & Data Cleared!", Toast.LENGTH_SHORT).show()
        }
        binding.btnClearCacheAction.setOnClickListener { clearCacheAction() }

        // Voice Search from Home Bottom Bar
        binding.btnHomeVoiceSearch.setOnClickListener {
            startVoiceSearch()
        }

        // Home Bottom Bar: Home
        binding.btnHomeHome.setOnClickListener {
            showHome()
        }

        // Home Bottom Bar: Now Playing (Resumes active playback in place)
        binding.btnHomeNowPlaying.setOnClickListener {
            showWeb()
        }

        // Floating Now Playing Banner Actions
        binding.layoutNowPlayingBanner.setOnClickListener {
            showWeb()
        }
        binding.btnBannerResume.setOnClickListener {
            showWeb()
        }
        binding.btnBannerPlayPause.setOnClickListener {
            if (isPlayingMedia) onMediaPause() else onMediaPlay()
        }

        // Home Bottom Bar: Settings (Scrolls down to settings card)
        binding.btnHomeSettings.setOnClickListener {
            binding.homeFavoritesView.post {
                binding.homeFavoritesView.smoothScrollTo(0, binding.homeFavoritesView.getChildAt(0).height)
            }
        }
    }

    private fun setSeekInterval(seconds: Int) {
        settingsManager.seekInterval = seconds
        binding.tvCurrentSeekStep.text = "${seconds}s"
        highlightSeekButton(seconds)
        updateSeekButtonLabels()
        Toast.makeText(this, "Steering Seek Step set to ${seconds}s", Toast.LENGTH_SHORT).show()
    }

    private fun highlightSeekButton(selectedStep: Int) {
        val accentColor = getColor(R.color.accent)
        val defaultColor = getColor(R.color.text_secondary)

        binding.btnSeek5s.setTextColor(if (selectedStep == 5) accentColor else defaultColor)
        binding.btnSeek10s.setTextColor(if (selectedStep == 10) accentColor else defaultColor)
        binding.btnSeek15s.setTextColor(if (selectedStep == 15) accentColor else defaultColor)
        binding.btnSeek30s.setTextColor(if (selectedStep == 30) accentColor else defaultColor)
    }

    private fun updateAdBlockUi(enabled: Boolean) {
        val color = if (enabled) getColor(R.color.accent) else getColor(R.color.text_secondary)
        binding.btnToggleAdBlock.setColorFilter(color)
        binding.tvAdBlockStatusDesc.text = if (enabled) "Block and skip all video and banner ads (Active)" else "Ad blocking disabled"
    }

    private fun updateDesktopUi(enabled: Boolean) {
        val color = if (enabled) getColor(R.color.accent) else getColor(R.color.text_secondary)
        binding.btnToggleDesktop.setColorFilter(color)
    }

    private fun showHome() {
        isHome = true
        binding.mainWebView.visibility = View.GONE
        binding.homeFavoritesView.visibility = View.VISIBLE
        binding.etSearchOrUrl.setText("")

        // Hide player controls, show home controls
        binding.mediaControlsGroup.visibility = View.GONE
        binding.homeControlsGroup.visibility = View.VISIBLE

        // Check if there is an active media session to display "Now Playing"
        val hasActiveMedia = !lastLoadedUrl.isNullOrBlank()
        binding.layoutNowPlayingBanner.visibility = if (hasActiveMedia) View.VISIBLE else View.GONE
        if (hasActiveMedia) {
            binding.tvBannerNowPlayingTitle.text = lastMediaTitle
            binding.btnBannerPlayPause.setImageResource(
                if (isPlayingMedia) R.drawable.ic_pause else R.drawable.ic_play
            )
            binding.ivHomeNowPlaying.setColorFilter(getColor(R.color.accent))
            binding.tvHomeNowPlaying.setTextColor(getColor(R.color.accent))
        } else {
            binding.ivHomeNowPlaying.setColorFilter(getColor(R.color.text_secondary))
            binding.tvHomeNowPlaying.setTextColor(getColor(R.color.text_secondary))
        }
    }

    private fun showWeb() {
        if (!lastLoadedUrl.isNullOrBlank()) {
            isHome = false
            binding.homeFavoritesView.visibility = View.GONE
            binding.layoutNowPlayingBanner.visibility = View.GONE
            binding.mainWebView.visibility = View.VISIBLE

            // Show player controls, hide home controls
            binding.mediaControlsGroup.visibility = View.VISIBLE
            binding.homeControlsGroup.visibility = View.GONE
            binding.mediaControlsGroup.post { binding.mediaControlsGroup.scrollTo(0, 0) }
        } else {
            loadUrl("https://m.youtube.com")
        }
    }

    private fun loadUrl(url: String) {
        lastLoadedUrl = url
        isHome = false
        binding.homeFavoritesView.visibility = View.GONE
        binding.layoutNowPlayingBanner.visibility = View.GONE
        binding.mainWebView.visibility = View.VISIBLE
        binding.mainWebView.loadUrl(url)

        // Show player controls, hide home controls
        binding.mediaControlsGroup.visibility = View.VISIBLE
        binding.homeControlsGroup.visibility = View.GONE
        binding.mediaControlsGroup.post { binding.mediaControlsGroup.scrollTo(0, 0) }

        // Also update car screen if connected
        carDisplayManager.currentPresentation?.loadUrl(url)
    }

    private fun performSearch(query: String) {
        val target = if (query.startsWith("http://") || query.startsWith("https://")) {
            query
        } else if (query.contains(".") && !query.contains(" ")) {
            "https://$query"
        } else {
            "https://www.google.com/search?q=" + java.net.URLEncoder.encode(query, "UTF-8")
        }
        loadUrl(target)
    }

    private fun startVoiceSearch() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_WEB_SEARCH)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Search Google with Voice…")
        }
        try {
            speechRecognizerLauncher.launch(intent)
        } catch (e: Exception) {
            Toast.makeText(this, "Voice search not available on this device", Toast.LENGTH_SHORT).show()
        }
    }

    private fun applyDesktopMode(isDesktop: Boolean) {
        val desktopUA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        binding.mainWebView.settings.userAgentString = if (isDesktop) desktopUA else null
    }

    private fun updatePlayPauseButtonUi(isPlaying: Boolean) {
        isPlayingMedia = isPlaying
        runOnUiThread {
            binding.btnNavPlayPause.setImageResource(
                if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play
            )
        }
    }

    // MARK: - MediaControlListener (Steering wheel and buttons)

    override fun onMediaPlay() {
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.TOGGLE_PLAY_PAUSE_SCRIPT, null)
        carDisplayManager.currentPresentation?.togglePlayPause()
        updatePlayPauseButtonUi(true)
        mediaSessionManager.updatePlaybackState(true, 0)
        KiaPlaybackService.startService(this, lastMediaTitle, true)
    }

    override fun onMediaPause() {
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.TOGGLE_PLAY_PAUSE_SCRIPT, null)
        carDisplayManager.currentPresentation?.togglePlayPause()
        updatePlayPauseButtonUi(false)
        mediaSessionManager.updatePlaybackState(false, 0)
        KiaPlaybackService.startService(this, lastMediaTitle, false)
    }

    override fun onMediaNext() {
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.NEXT_TRACK_SCRIPT, null)
        carDisplayManager.currentPresentation?.nextVideo()
    }

    override fun onMediaPrevious() {
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.PREV_TRACK_SCRIPT, null)
        carDisplayManager.currentPresentation?.previousVideo()
    }

    override fun onMediaSeekForward(deltaSeconds: Int) {
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.seekScript(deltaSeconds), null)
        carDisplayManager.currentPresentation?.seekForward(deltaSeconds)
    }

    override fun onMediaSeekBackward(deltaSeconds: Int) {
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.seekScript(-deltaSeconds), null)
        carDisplayManager.currentPresentation?.seekBackward(deltaSeconds)
    }

    override fun onMediaSeekTo(positionMs: Long) {
        val seconds = positionMs / 1000.0
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.seekToScript(seconds), null)
        carDisplayManager.currentPresentation?.seekTo(seconds)
    }

    // MARK: - KiaPlaybackService.PlaybackCallback

    override fun onServicePlayPause() {
        if (isPlayingMedia) onMediaPause() else onMediaPlay()
    }

    override fun onServiceRewind(seconds: Int) {
        onMediaSeekBackward(seconds)
    }

    override fun onServiceForward(seconds: Int) {
        onMediaSeekForward(seconds)
    }

    override fun onServiceNext() {
        onMediaNext()
    }

    override fun onServicePrevious() {
        onMediaPrevious()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (!isHome && binding.mainWebView.canGoBack()) {
            binding.mainWebView.goBack()
        } else if (!isHome) {
            showHome()
        } else {
            super.onBackPressed()
        }
    }
}
