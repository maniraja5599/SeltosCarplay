package com.seltos.kiabrowser

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.util.Log
import android.view.Display

class KiaCarDisplayManager(
    private val context: Context,
    private val onPresentationStateChanged: ((isAttached: Boolean, presentation: KiaCarPresentation?) -> Unit)? = null
) : DisplayManager.DisplayListener {

    private val displayManager: DisplayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    var currentPresentation: KiaCarPresentation? = null
        private set

    companion object {
        private const val TAG = "KiaCarDisplayManager"
    }

    fun startListening() {
        try {
            displayManager.registerDisplayListener(this, null)
            checkForConnectedCarDisplay()
        } catch (e: Exception) {
            Log.e(TAG, "Error starting display listener: ${e.message}")
        }
    }

    fun stopListening() {
        try {
            displayManager.unregisterDisplayListener(this)
            dismissPresentation()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping display listener: ${e.message}")
        }
    }

    private fun checkForConnectedCarDisplay() {
        try {
            val displays = displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            if (displays.isNotEmpty()) {
                showPresentationOnDisplay(displays[0])
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking connected displays: ${e.message}")
        }
    }

    private fun showPresentationOnDisplay(display: Display) {
        if (currentPresentation != null) return

        // Safety check: ensure activity is not destroyed
        if (context is Activity && (context.isFinishing || context.isDestroyed)) {
            Log.w(TAG, "Activity is finishing or destroyed, ignoring display presentation")
            return
        }

        try {
            val presentation = KiaCarPresentation(context, display)
            presentation.setOnDismissListener {
                currentPresentation = null
                onPresentationStateChanged?.invoke(false, null)
            }
            presentation.show()
            currentPresentation = presentation
            onPresentationStateChanged?.invoke(true, presentation)
            Log.i(TAG, "Successfully showed KiaCarPresentation on car display ${display.displayId}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show presentation on car display: ${e.message}")
            // Gracefully catch any WindowManager$BadTokenException or SecurityException
            dismissPresentation()
            onPresentationStateChanged?.invoke(false, null)
        }
    }

    private fun dismissPresentation() {
        try {
            currentPresentation?.dismiss()
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing presentation: ${e.message}")
        } finally {
            currentPresentation = null
        }
    }

    override fun onDisplayAdded(displayId: Int) {
        try {
            val display = displayManager.getDisplay(displayId) ?: return
            val isPresentation = (display.flags and Display.FLAG_PRESENTATION) != 0
            if (isPresentation) {
                showPresentationOnDisplay(display)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error onDisplayAdded: ${e.message}")
        }
    }

    override fun onDisplayRemoved(displayId: Int) {
        if (currentPresentation?.display?.displayId == displayId) {
            dismissPresentation()
            onPresentationStateChanged?.invoke(false, null)
        }
    }

    override fun onDisplayChanged(displayId: Int) {}
}
