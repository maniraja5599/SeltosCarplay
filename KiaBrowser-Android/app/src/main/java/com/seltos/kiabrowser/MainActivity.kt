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

        // Inject anti-pause at document start before YouTube page scripts execute
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(
                binding.mainWebView,
                YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT,
                setOf("*")
            )
        }

        binding.mainWebView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                binding.loadingProgress.visibility = View.VISIBLE
                binding.mainWebView.evaluateJavascript(YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT, null)
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
                mediaSessionManager.updateMetadata(title, "Kia Browser", 0)
                mediaSessionManager.updatePlaybackState(true, 0)

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
            binding.btnToggleDesktop.setColorFilter(
                if (newMode) getColor(R.color.accent) else getColor(R.color.text_secondary)
            )
            Toast.makeText(this, if (newMode) "Desktop Site Enabled" else "Mobile Site Enabled", Toast.LENGTH_SHORT).show()
            if (!isHome) {
                binding.mainWebView.reload()
            }
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

    private fun showHome() {
        isHome = true
        binding.mainWebView.visibility = View.GONE
        binding.homeFavoritesView.visibility = View.VISIBLE
        binding.etSearchOrUrl.setText("")
    }

    private fun loadUrl(url: String) {
        isHome = false
        binding.homeFavoritesView.visibility = View.GONE
        binding.mainWebView.visibility = View.VISIBLE
        binding.mainWebView.loadUrl(url)

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

    // MARK: - MediaControlListener (Steering wheel and buttons)

    override fun onMediaPlay() {
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.TOGGLE_PLAY_PAUSE_SCRIPT, null)
        carDisplayManager.currentPresentation?.togglePlayPause()
        KiaPlaybackService.startService(this, lastMediaTitle, true)
    }

    override fun onMediaPause() {
        binding.mainWebView.evaluateJavascript(YouTubeWebHelper.TOGGLE_PLAY_PAUSE_SCRIPT, null)
        carDisplayManager.currentPresentation?.togglePlayPause()
        KiaPlaybackService.startService(this, lastMediaTitle, false)
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
        onMediaPlay()
    }

    override fun onServiceRewind(seconds: Int) {
        onMediaSeekBackward(seconds)
    }

    override fun onServiceForward(seconds: Int) {
        onMediaSeekForward(seconds)
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
