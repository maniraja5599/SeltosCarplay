package com.seltos.kiabrowser

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaDescriptionCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.MediaBrowserServiceCompat

class KiaPlaybackService : MediaBrowserServiceCompat() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var isPlaying = false
    private var currentTitle = "YouTube & Media"
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    companion object {
        const val TAG = "KiaPlaybackService"
        const val CHANNEL_ID = "kia_browser_playback_channel"
        const val NOTIFICATION_ID = 1001

        const val MEDIA_ROOT_ID = "kia_browser_root"
        const val MEDIA_ID_YOUTUBE = "media_youtube"
        const val MEDIA_ID_CRICKET = "media_cricket"
        const val MEDIA_ID_HOTSTAR = "media_hotstar"

        const val ACTION_START_PLAYBACK = "com.seltos.kiabrowser.START_PLAYBACK"
        const val ACTION_STOP_PLAYBACK = "com.seltos.kiabrowser.STOP_PLAYBACK"
        const val ACTION_PLAY_PAUSE = "com.seltos.kiabrowser.PLAY_PAUSE"
        const val ACTION_REWIND = "com.seltos.kiabrowser.REWIND"
        const val ACTION_FORWARD = "com.seltos.kiabrowser.FORWARD"
        const val ACTION_NEXT = "com.seltos.kiabrowser.NEXT"
        const val ACTION_PREVIOUS = "com.seltos.kiabrowser.PREVIOUS"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_IS_PLAYING = "extra_is_playing"

        var activeCallback: PlaybackCallback? = null
        var instance: KiaPlaybackService? = null
        var mediaSessionInstance: MediaSessionCompat? = null

        fun startService(context: Context, title: String, isPlaying: Boolean) {
            val intent = Intent(context, KiaPlaybackService::class.java).apply {
                action = ACTION_START_PLAYBACK
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_IS_PLAYING, isPlaying)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Ignore background start exceptions
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, KiaPlaybackService::class.java).apply {
                action = ACTION_STOP_PLAYBACK
            }
            context.stopService(intent)
        }
    }

    interface PlaybackCallback {
        fun onServicePlayPause()
        fun onServiceRewind(seconds: Int)
        fun onServiceForward(seconds: Int)
        fun onServiceNext()
        fun onServicePrevious()
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate initialized")
        instance = this
        createNotificationChannel()
        acquireWakeLock()
        requestAudioFocus()
        setupMediaSession()
    }

    private fun setupMediaSession() {
        if (mediaSessionInstance == null) {
            Log.d(TAG, "Setting up MediaSessionCompat")
            mediaSessionInstance = MediaSessionCompat(this, "KiaBrowserMediaSession").apply {
                setFlags(
                    MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
                )

                val queue = listOf(
                    MediaSessionCompat.QueueItem(buildMediaDescription(MEDIA_ID_YOUTUBE, "YouTube & Media", "Browser Live"), 1),
                    MediaSessionCompat.QueueItem(buildMediaDescription(MEDIA_ID_CRICKET, "Live Cricket Score", "Cricket Hub"), 2),
                    MediaSessionCompat.QueueItem(buildMediaDescription(MEDIA_ID_HOTSTAR, "Hotstar & Apps", "Web Video"), 3)
                )
                setQueue(queue)

                setCallback(object : MediaSessionCompat.Callback() {
                    override fun onPrepare() {
                        Log.d(TAG, "MediaSession onPrepare")
                        onPlay()
                    }

                    override fun onPrepareFromMediaId(mediaId: String?, extras: Bundle?) {
                        Log.d(TAG, "MediaSession onPrepareFromMediaId: $mediaId")
                        onPlayFromMediaId(mediaId, extras)
                    }

                    override fun onPlayFromSearch(query: String?, extras: Bundle?) {
                        Log.d(TAG, "MediaSession onPlayFromSearch: $query")
                        onPlayFromMediaId(MEDIA_ID_YOUTUBE, extras)
                    }

                    override fun onSkipToQueueItem(queueId: Long) {
                        Log.d(TAG, "MediaSession onSkipToQueueItem: $queueId")
                        val mediaId = when (queueId) {
                            2L -> MEDIA_ID_CRICKET
                            3L -> MEDIA_ID_HOTSTAR
                            else -> MEDIA_ID_YOUTUBE
                        }
                        onPlayFromMediaId(mediaId, null)
                    }

                    override fun onPlay() {
                        Log.d(TAG, "MediaSession onPlay")
                        isPlaying = true
                        activeCallback?.onServicePlayPause()
                        updatePlaybackState(true, 0)
                        startForegroundWithNotification()
                    }

                    override fun onPause() {
                        Log.d(TAG, "MediaSession onPause")
                        isPlaying = false
                        activeCallback?.onServicePlayPause()
                        updatePlaybackState(false, 0)
                        startForegroundWithNotification()
                    }

                    override fun onSkipToNext() {
                        Log.d(TAG, "MediaSession onSkipToNext")
                        activeCallback?.onServiceNext()
                    }

                    override fun onSkipToPrevious() {
                        Log.d(TAG, "MediaSession onSkipToPrevious")
                        activeCallback?.onServicePrevious()
                    }

                    override fun onFastForward() {
                        val step = SettingsManager.getInstance(this@KiaPlaybackService).seekInterval
                        activeCallback?.onServiceForward(step)
                    }

                    override fun onRewind() {
                        val step = SettingsManager.getInstance(this@KiaPlaybackService).seekInterval
                        activeCallback?.onServiceRewind(step)
                    }

                    override fun onPlayFromMediaId(mediaId: String?, extras: Bundle?) {
                        Log.d(TAG, "MediaSession onPlayFromMediaId: $mediaId")
                        val selectedId = mediaId ?: MEDIA_ID_YOUTUBE
                        val title = when (selectedId) {
                            MEDIA_ID_CRICKET -> "Live Cricket Center"
                            MEDIA_ID_HOTSTAR -> "Hotstar Streaming"
                            else -> "YouTube & Media"
                        }
                        val targetUrl = when (selectedId) {
                            MEDIA_ID_CRICKET -> "file:///android_asset/cricket_hub.html?match=0"
                            MEDIA_ID_HOTSTAR -> "https://www.hotstar.com/in"
                            else -> "https://m.youtube.com"
                        }

                        currentTitle = title
                        isPlaying = true

                        // 1. Immediately update metadata so Android Auto displays player HUD without error
                        updateMetadata(title, "Kia Browser", -1L, selectedId)

                        // 2. Transition state to PLAYING
                        updatePlaybackState(true, 0)

                        // 3. Keep foreground service alive with notification
                        startForegroundWithNotification()

                        // 4. Trigger MainActivity to load the target URL
                        try {
                            val intent = Intent(this@KiaPlaybackService, MainActivity::class.java).apply {
                                data = Uri.parse(targetUrl)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to start MainActivity from service", e)
                        }

                        activeCallback?.onServicePlayPause()
                    }
                })

                isActive = true
            }

            // Pre-populate session immediately so Android Auto never sees null PlaybackState
            updateMetadata("YouTube & Media", "Kia Browser Live", -1L, MEDIA_ID_YOUTUBE)
            updatePlaybackState(true, 0)
        }

        sessionToken = mediaSessionInstance?.sessionToken
    }

    override fun onGetRoot(
        clientPackageName: String,
        clientUid: Int,
        rootHints: Bundle?
    ): BrowserRoot {
        Log.d(TAG, "onGetRoot called by $clientPackageName (uid: $clientUid)")
        val extras = Bundle().apply {
            putBoolean("android.media.browse.SEARCH_SUPPORTED", true)
            putBoolean("android.media.browse.CONTENT_STYLE_SUPPORTED", true)
            putInt("android.media.browse.CONTENT_STYLE_BROWSABLE_HINT", 1)
            putInt("android.media.browse.CONTENT_STYLE_PLAYABLE_HINT", 1)
        }
        return BrowserRoot(MEDIA_ROOT_ID, extras)
    }

    override fun onLoadChildren(
        parentId: String,
        result: Result<MutableList<MediaBrowserCompat.MediaItem>>
    ) {
        Log.d(TAG, "onLoadChildren for parentId: $parentId")
        val items = mutableListOf<MediaBrowserCompat.MediaItem>()
        if (parentId == MEDIA_ROOT_ID) {
            items.add(buildMediaItem(MEDIA_ID_YOUTUBE, "YouTube & Media", "Resume active browser playback"))
            items.add(buildMediaItem(MEDIA_ID_CRICKET, "Live Cricket Score", "Live match commentary & scores"))
            items.add(buildMediaItem(MEDIA_ID_HOTSTAR, "Hotstar & Apps", "Stream web video directly"))
        } else {
            items.add(buildMediaItem(MEDIA_ID_YOUTUBE, "YouTube & Media", "Resume active browser playback"))
        }
        result.sendResult(items)
    }

    private fun buildMediaDescription(id: String, title: String, subtitle: String): MediaDescriptionCompat {
        val iconUri = Uri.parse("android.resource://${packageName}/drawable/app_logo")
        return MediaDescriptionCompat.Builder()
            .setMediaId(id)
            .setTitle(title)
            .setSubtitle(subtitle)
            .setDescription(subtitle)
            .setIconUri(iconUri)
            .build()
    }

    private fun buildMediaItem(id: String, title: String, subtitle: String): MediaBrowserCompat.MediaItem {
        val desc = buildMediaDescription(id, title, subtitle)
        return MediaBrowserCompat.MediaItem(desc, MediaBrowserCompat.MediaItem.FLAG_PLAYABLE)
    }

    fun updatePlaybackState(playing: Boolean, positionMs: Long = 0) {
        isPlaying = playing
        val state = if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val actions = PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_FAST_FORWARD or
                PlaybackStateCompat.ACTION_REWIND or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_PLAY_FROM_MEDIA_ID or
                PlaybackStateCompat.ACTION_SEEK_TO

        val playbackState = PlaybackStateCompat.Builder()
            .setActions(actions)
            .setState(state, positionMs, 1.0f)
            .build()

        mediaSessionInstance?.setPlaybackState(playbackState)
    }

    fun updateMetadata(
        title: String,
        artist: String = "Kia Browser",
        durationMs: Long = -1L,
        mediaId: String = MEDIA_ID_YOUTUBE
    ) {
        currentTitle = title
        val artBitmap = try {
            android.graphics.BitmapFactory.decodeResource(resources, R.drawable.app_logo)
        } catch (_: Exception) {
            null
        }

        val builder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, mediaId)
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Kia Seltos Infotainment")
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)

        if (artBitmap != null) {
            builder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, artBitmap)
            builder.putBitmap(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON, artBitmap)
        }

        mediaSessionInstance?.setMetadata(builder.build())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_STICKY

        when (action) {
            ACTION_START_PLAYBACK -> {
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: "Kia Browser"
                isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, true)
                updatePlaybackState(isPlaying, 0)
                updateMetadata(currentTitle)
                startForegroundWithNotification()
            }
            ACTION_PLAY_PAUSE -> {
                isPlaying = !isPlaying
                activeCallback?.onServicePlayPause()
                updatePlaybackState(isPlaying, 0)
                startForegroundWithNotification()
            }
            ACTION_REWIND -> {
                val step = SettingsManager.getInstance(this).seekInterval
                activeCallback?.onServiceRewind(step)
            }
            ACTION_FORWARD -> {
                val step = SettingsManager.getInstance(this).seekInterval
                activeCallback?.onServiceForward(step)
            }
            ACTION_NEXT -> {
                activeCallback?.onServiceNext()
            }
            ACTION_PREVIOUS -> {
                activeCallback?.onServicePrevious()
            }
            ACTION_STOP_PLAYBACK -> {
                stopForeground(true)
                stopSelf()
            }
        }

        return START_STICKY
    }

    private fun startForegroundWithNotification() {
        val notification = buildNotification(currentTitle, isPlaying)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(title: String, isPlaying: Boolean): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val rewindIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, KiaPlaybackService::class.java).apply { action = ACTION_REWIND },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val playPauseIntent = PendingIntent.getService(
            this,
            2,
            Intent(this, KiaPlaybackService::class.java).apply { action = ACTION_PLAY_PAUSE },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val forwardIntent = PendingIntent.getService(
            this,
            3,
            Intent(this, KiaPlaybackService::class.java).apply { action = ACTION_FORWARD },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = PendingIntent.getService(
            this,
            4,
            Intent(this, KiaPlaybackService::class.java).apply { action = ACTION_STOP_PLAYBACK },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val step = SettingsManager.getInstance(this).seekInterval

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("Kia Seltos Audio Active • Seek: ${step}s")
            .setContentIntent(contentIntent)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(mediaSessionInstance?.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .addAction(R.drawable.ic_replay_5, "-${step}s", rewindIntent)
            .addAction(
                if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play,
                if (isPlaying) "Pause" else "Play",
                playPauseIntent
            )
            .addAction(R.drawable.ic_forward_5, "+${step}s", forwardIntent)
            .addAction(R.drawable.ic_arrow_back, "Stop", stopIntent)

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Kia Browser Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background media playback and in-car controls"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "KiaBrowser::MediaWakeLock"
            )
            wakeLock?.acquire(4 * 60 * 60 * 1000L) // 4 hours max
        }
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        wakeLock = null
    }

    private fun requestAudioFocus() {
        try {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(audioAttributes)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener { /* Keep playing */ }
                    .build()
                audioManager?.requestAudioFocus(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(
                    { /* Keep playing */ },
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN
                )
            }
        } catch (_: Exception) {}
    }

    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        releaseWakeLock()
        abandonAudioFocus()
    }

    override fun onBind(intent: Intent?): IBinder? {
        if (SERVICE_INTERFACE == intent?.action) {
            return super.onBind(intent)
        }
        return super.onBind(intent)
    }
}
