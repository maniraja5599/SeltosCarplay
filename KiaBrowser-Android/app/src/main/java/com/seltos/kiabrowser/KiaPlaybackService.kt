package com.seltos.kiabrowser

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class KiaPlaybackService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var isPlaying = true
    private var currentTitle = "Kia Browser"
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    companion object {
        const val CHANNEL_ID = "kia_browser_playback_channel"
        const val NOTIFICATION_ID = 1001

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

        fun startService(context: Context, title: String, isPlaying: Boolean) {
            val intent = Intent(context, KiaPlaybackService::class.java).apply {
                action = ACTION_START_PLAYBACK
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_IS_PLAYING, isPlaying)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
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
        createNotificationChannel()
        acquireWakeLock()
        requestAudioFocus()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_STICKY

        when (action) {
            ACTION_START_PLAYBACK -> {
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: "Kia Browser"
                isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, true)
                startForegroundWithNotification()
            }
            ACTION_PLAY_PAUSE -> {
                isPlaying = !isPlaying
                activeCallback?.onServicePlayPause()
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

        // Actions: Rewind, Play/Pause, Forward
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
        releaseWakeLock()
        abandonAudioFocus()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
