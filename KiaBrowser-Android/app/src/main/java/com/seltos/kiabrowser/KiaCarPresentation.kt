package com.seltos.kiabrowser

import android.app.Presentation
import android.content.Context
import android.graphics.Bitmap
import android.os.Bundle
import android.view.Display
import android.view.View
import android.webkit.*
import android.widget.TextView
import androidx.appcompat.view.ContextThemeWrapper
import androidx.appcompat.widget.AppCompatImageButton
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature

class KiaCarPresentation(
    outerContext: Context,
    display: Display,
    private val initialUrl: String = "https://m.youtube.com",
    private val onMediaStateChanged: ((title: String, isPlaying: Boolean) -> Unit)? = null
) : Presentation(ContextThemeWrapper(outerContext, R.style.Theme_KiaBrowser), display, R.style.Theme_KiaBrowser) {

    private lateinit var carWebView: WebView
    private lateinit var carTitleText: TextView
    private lateinit var btnCarHome: AppCompatImageButton
    private lateinit var btnCarBack: AppCompatImageButton
    private lateinit var btnCarRefresh: AppCompatImageButton
    private lateinit var btnCarPlayPause: AppCompatImageButton
    private lateinit var btnCarPrevious: AppCompatImageButton
    private lateinit var btnCarNext: AppCompatImageButton
    private lateinit var btnCarRewind5: AppCompatImageButton
    private lateinit var btnCarForward5: AppCompatImageButton
    private lateinit var btnCarFullscreen: AppCompatImageButton
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
        btnCarPrevious = findViewById(R.id.btnCarPrevious)
        btnCarNext = findViewById(R.id.btnCarNext)
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
        val cookieManager = android.webkit.CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setAcceptThirdPartyCookies(carWebView, true)

        val settings = carWebView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.setSupportMultipleWindows(false)
        settings.javaScriptCanOpenWindowsAutomatically = true
        settings.mediaPlaybackRequiresUserGesture = false
        settings.allowFileAccess = true
        settings.loadWithOverviewMode = true
        settings.useWideViewPort = true

        val isDesktop = SettingsManager.getInstance(context).isDesktopMode
        settings.userAgentString =
            if (isDesktop) YouTubeWebHelper.CHROME_DESKTOP_UA else YouTubeWebHelper.CHROME_MOBILE_UA

        // Inject anti-pause and ad-block at document start before YouTube page scripts execute
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(
                carWebView,
                YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT,
                setOf("*")
            )
            WebViewCompat.addDocumentStartJavaScript(
                carWebView,
                YouTubeWebHelper.AD_AND_PROMO_SUPPRESSION_SCRIPT,
                setOf("*")
            )
        }

        carWebView.addJavascriptInterface(CarMediaBridge(), "CarMediaBridge")

        carWebView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?
            ): WebResourceResponse? {
                val url = request?.url?.toString()
                if (YouTubeWebHelper.isAdUrl(url)) {
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
                carWebView.evaluateJavascript(YouTubeWebHelper.ANTI_BACKGROUND_PAUSE_SCRIPT, null)
                carWebView.evaluateJavascript(YouTubeWebHelper.AD_AND_PROMO_SUPPRESSION_SCRIPT, null)
            }

            override fun onLoadResource(view: WebView?, url: String?) {
                super.onLoadResource(view, url)
                if (YouTubeWebHelper.isYouTubeUrl(view?.url)) {
                    carWebView.evaluateJavascript(YouTubeWebHelper.AD_AND_PROMO_SUPPRESSION_SCRIPT, null)
                }
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

        btnCarPrevious.setOnClickListener {
            previousVideo()
        }

        btnCarNext.setOnClickListener {
            nextVideo()
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

    fun nextVideo() {
        carWebView.evaluateJavascript(YouTubeWebHelper.NEXT_TRACK_SCRIPT, null)
    }

    fun previousVideo() {
        carWebView.evaluateJavascript(YouTubeWebHelper.PREV_TRACK_SCRIPT, null)
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
