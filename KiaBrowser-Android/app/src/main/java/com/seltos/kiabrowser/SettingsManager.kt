package com.seltos.kiabrowser

import android.content.Context
import android.content.SharedPreferences

class SettingsManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("kia_browser_prefs", Context.MODE_PRIVATE)

    var seekInterval: Int
        get() = prefs.getInt(KEY_SEEK_INTERVAL, 5) // Default 5 seconds
        set(value) = prefs.edit().putInt(KEY_SEEK_INTERVAL, value).apply()

    var isDesktopMode: Boolean
        get() = prefs.getBoolean(KEY_DESKTOP_MODE, false)
        set(value) = prefs.edit().putBoolean(KEY_DESKTOP_MODE, value).apply()

    var isAdBlockEnabled: Boolean
        get() = prefs.getBoolean(KEY_AD_BLOCK, true)
        set(value) = prefs.edit().putBoolean(KEY_AD_BLOCK, value).apply()

    companion object {
        private const val KEY_SEEK_INTERVAL = "seek_interval"
        private const val KEY_DESKTOP_MODE = "desktop_mode"
        private const val KEY_AD_BLOCK = "ad_block"

        @Volatile
        private var instance: SettingsManager? = null

        fun getInstance(context: Context): SettingsManager {
            return instance ?: synchronized(this) {
                instance ?: SettingsManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
