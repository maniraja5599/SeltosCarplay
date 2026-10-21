package com.seltos.kiabrowser

import android.content.Context
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat

interface MediaControlListener {
    fun onMediaPlay()
    fun onMediaPause()
    fun onMediaSeekForward(deltaSeconds: Int)
    fun onMediaSeekBackward(deltaSeconds: Int)
    fun onMediaSeekTo(positionMs: Long)
    fun onMediaNext()
    fun onMediaPrevious()
}

class KiaMediaSessionManager(
    private val context: Context,
    private val listener: MediaControlListener
) {
    private var mediaSession: MediaSessionCompat? = null

    init {
        setupMediaSession()
    }

    private fun setupMediaSession() {
        val existing = KiaPlaybackService.mediaSessionInstance
        if (existing != null) {
            mediaSession = existing
        } else {
            mediaSession = MediaSessionCompat(context, "KiaBrowserMediaSession").apply {
                setFlags(
                    MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
                )
                isActive = true
            }
            KiaPlaybackService.mediaSessionInstance = mediaSession
        }

        mediaSession?.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() {
                listener.onMediaPlay()
                updatePlaybackState(true, 0)
            }

            override fun onPause() {
                listener.onMediaPause()
                updatePlaybackState(false, 0)
            }

            override fun onSkipToNext() {
                listener.onMediaNext()
            }

            override fun onSkipToPrevious() {
                listener.onMediaPrevious()
            }

            override fun onFastForward() {
                val step = SettingsManager.getInstance(context).seekInterval
                listener.onMediaSeekForward(step)
            }

            override fun onRewind() {
                val step = SettingsManager.getInstance(context).seekInterval
                listener.onMediaSeekBackward(step)
            }

            override fun onSeekTo(pos: Long) {
                listener.onMediaSeekTo(pos)
            }
        })
    }

    fun updatePlaybackState(isPlaying: Boolean, positionMs: Long) {
        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val actions = PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_FAST_FORWARD or
                PlaybackStateCompat.ACTION_REWIND or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO

        val playbackState = PlaybackStateCompat.Builder()
            .setActions(actions)
            .setState(state, positionMs, 1.0f)
            .build()

        mediaSession?.setPlaybackState(playbackState)
    }

    fun updateMetadata(title: String, artist: String, durationMs: Long) {
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
            .build()

        mediaSession?.setMetadata(metadata)
    }

    fun release() {
        if (KiaPlaybackService.instance == null) {
            mediaSession?.isActive = false
            mediaSession?.release()
            KiaPlaybackService.mediaSessionInstance = null
        }
        mediaSession = null
    }
}
