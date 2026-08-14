package com.zequetech.spectacular_barcode

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.Surface
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel

internal class DeviceOrientationListener(
    private val activity: Activity,
) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var lastOrientation: String? = null
    var onDisplayRotationChanged: ((Int) -> Unit)? = null

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            onDisplayRotationChanged?.invoke(getDisplay().rotation)
            sendOrientationIfChanged()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        sendOrientationIfChanged(force = true)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun start() {
        val displayManager =
            activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(
            displayListener,
            Handler(Looper.getMainLooper()),
        )
        sendOrientationIfChanged(force = true)
    }

    fun stop() {
        val displayManager =
            activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.unregisterDisplayListener(displayListener)
        onDisplayRotationChanged = null
    }

    @Suppress("DEPRECATION")
    fun getDisplay(): Display {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.let { return it }
        }
        return (activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager)
            .defaultDisplay
    }

    fun getOrientation(): String {
        return when (getDisplay().rotation) {
            Surface.ROTATION_0 -> "PORTRAIT_UP"
            Surface.ROTATION_90 -> "LANDSCAPE_LEFT"
            Surface.ROTATION_180 -> "PORTRAIT_DOWN"
            Surface.ROTATION_270 -> "LANDSCAPE_RIGHT"
            else -> "PORTRAIT_UP"
        }
    }

    private fun sendOrientationIfChanged(force: Boolean = false) {
        val orientation = getOrientation()
        if (!force && orientation == lastOrientation) {
            return
        }
        lastOrientation = orientation
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(orientation)
        }
    }
}
