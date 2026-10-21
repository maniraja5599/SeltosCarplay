package com.seltos.kiabrowser

import android.app.Presentation
import android.content.Context
import android.graphics.Bitmap
import android.os.Bundle
import android.view.Display
import android.view.View
import android.webkit.*
import android.widget.ImageButton
import android.widget.TextView

class KiaCarPresentation(
    outerContext: Context,
    display: Display,
    private val initialUrl: String = "https://m.youtube.com",
    private val onMediaStateChanged: ((title: String, isPlaying: Boolean) -> Unit)? = null
) : Presentation(outerContext, display) {

    private lateinit var carWebView: WebView
    private lateinit var carTitleText: TextView
    private lateinit var btnCarHome: ImageButton
    private lateinit var btnCarBack: ImageButton
    private lateinit var btnCarRefresh: ImageButton
    private lateinit var btnCarPlayPause: ImageButton
    private lateinit var btnCarRewind5: ImageButton
    private lateinit var btnCarForward5: ImageButton
    private lateinit var btnCarFullscreen: ImageButton
    private lateinit var tvCarRewindLabel: TextView
    private lateinit var tvCarForwardLabel: TextView

    private var isPlaying = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.presentation_car_browser)

        carWebView = findViewById(R.id.carWebView)
        carTitleText = findViewById(R.id.carTitleText)
        btnCarHome = findViewById(R.id.btnCarHome)
        btnCarBack = findViewById(R.id.btnCarBack)
        btnCarRefresh = findViewById(R.id.btnCarRefresh)
        btnCarPlayPause = findViewById(R.id.btnCarPlayPause)
        btnCarRewind5 = findViewById(R.id.btnCarRewind5)
        btnCarForward5 = findViewById(R.id.btnCarForward5)
        btnCarFullscreen = findViewById(R.id.btnCarFullscreen)
        tvCarRewindLabel = findViewById(R.id.tvCarRewindLabel)
        tvCarForwardLabel = findViewById(R.id.tvCarForwardLabel)

        updateSeekLabels()
        setupWebView()
        setupListeners()

        carWebView.loadUrl(initialUrl)
    }

    private fun updateSeekLabels() {
        val step = SettingsManager.getInstance(context).seekInterval
        val text = "${step}s"
        tvCarRewindLabel.text = text
        tvCarForwardLabel.text = text
    }

    private fun setupWebView() {
        val settings = carWebView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.mediaPlaybackRequiresUserGesture = false
        settings.allowFileAccess = true
        settings.loadWithOverviewMode = true
        settings.useWideViewPort = true
        settings.databaseEnabled = true

        val isDesktop = SettingsManager.getInstance(context).isDesktopMode
        if (isDesktop) {
            settings.userAgentString = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }

        carWebView.addJavascriptInterface(CarMediaBridge(), "CarMediaBridge")

        carWebView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                carWebView.evaluateJavascript(YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT, null)
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                carTitleText.text = view?.title ?: "Kia Browser"
                carWebView.evaluateJavascript(YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT, null)
                carWebView.evaluateJavascript(YouTubeWebHelper.AD_AND_PROMO_SUPPRESSION_SCRIPT, null)
            }
        }

        carWebView.webChromeClient = object : WebChromeClient() {
            override fun onReceivedTitle(view: WebView?, title: String?) {
                super.onReceivedTitle(view, title)
                carTitleText.text = title ?: "Kia Browser"
            }
        }
    }

    private fun setupListeners() {
        btnCarHome.setOnClickListener {
            carWebView.loadUrl("https://m.youtube.com")
        }

        btnCarBack.setOnClickListener {
            if (carWebView.canGoBack()) {
                carWebView.goBack()
            }
        }

        btnCarRefresh.setOnClickListener {
            carWebView.reload()
        }

        btnCarPlayPause.setOnClickListener {
            togglePlayPause()
        }

        btnCarRewind5.setOnClickListener {
            seekBackward()
        }

        btnCarForward5.setOnClickListener {
            seekForward()
        }

        btnCarFullscreen.setOnClickListener {
            toggleFullscreen()
        }
    }

    fun loadUrl(url: String) {
        carWebView.loadUrl(url)
    }

    fun seekForward(seconds: Int = SettingsManager.getInstance(context).seekInterval) {
        carWebView.evaluateJavascript(YouTubeWebHelper.seekScript(seconds), null)
    }

    fun seekBackward(seconds: Int = SettingsManager.getInstance(context).seekInterval) {
        carWebView.evaluateJavascript(YouTubeWebHelper.seekScript(-seconds), null)
    }

    fun seekTo(positionSeconds: Double) {
        carWebView.evaluateJavascript(YouTubeWebHelper.seekToScript(positionSeconds), null)
    }

    fun togglePlayPause() {
        carWebView.evaluateJavascript(YouTubeWebHelper.TOGGLE_PLAY_PAUSE_SCRIPT, null)
        isPlaying = !isPlaying
        btnCarPlayPause.setImageResource(if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play)
        onMediaStateChanged?.invoke(carTitleText.text.toString(), isPlaying)
    }

    private fun toggleFullscreen() {
        val topBar = findViewById<View>(R.id.carTopBar)
        if (topBar.visibility == View.VISIBLE) {
            topBar.visibility = View.GONE
        } else {
            topBar.visibility = View.VISIBLE
        }
    }

    inner class CarMediaBridge {
        @JavascriptInterface
        fun postMediaState(title: String, playing: Boolean) {
            carWebView.post {
                isPlaying = playing
                carTitleText.text = title
                btnCarPlayPause.setImageResource(if (playing) R.drawable.ic_pause else R.drawable.ic_play)
                onMediaStateChanged?.invoke(title, playing)
            }
        }
    }
}
