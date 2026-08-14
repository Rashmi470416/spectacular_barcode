package com.zequetech.spectacular_barcode

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

internal class BarcodeEventHandler(
    binaryMessenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    private val eventChannel = EventChannel(
        binaryMessenger,
        "com.zequetech.spectacular_barcode/scanner/event",
    )

    init {
        eventChannel.setStreamHandler(this)
    }

    fun publishError(errorCode: String, errorMessage: String, errorDetails: Any?) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.error(errorCode, errorMessage, errorDetails)
        }
    }

    fun publishEvent(event: Map<String, Any?>) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(event)
        }
    }

    fun dispose() {
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
