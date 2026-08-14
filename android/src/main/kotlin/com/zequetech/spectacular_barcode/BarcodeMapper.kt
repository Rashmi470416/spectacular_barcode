package com.zequetech.spectacular_barcode

import android.graphics.Point
import android.graphics.Rect
import com.google.mlkit.vision.barcode.common.Barcode

internal val Barcode.data: Map<String, Any?>
    get() = mapOf(
        "corners" to cornerPoints?.map { it.data },
        "displayValue" to displayValue,
        "format" to format.toDartFormat(),
        "rawBytes" to rawBytes,
        "rawValue" to rawValue,
        "size" to boundingBox?.size,
        "type" to valueType,
    )

private val Point.data: Map<String, Double>
    get() = mapOf("x" to x.toDouble(), "y" to y.toDouble())

private val Rect.size: Map<String, Any?>
    get() {
        if (left <= right && top <= bottom) {
            return mapOf(
                "width" to width().toDouble(),
                "height" to height().toDouble(),
            )
        }
        return emptyMap()
    }

/**
 * Map ML Kit format constants to the Dart [BarcodeFormat] raw values used by this plugin.
 */
private fun Int.toDartFormat(): Int {
    return when (this) {
        Barcode.FORMAT_UNKNOWN -> -1
        Barcode.FORMAT_ALL_FORMATS -> 0
        Barcode.FORMAT_CODE_128 -> 1
        Barcode.FORMAT_CODE_39 -> 2
        Barcode.FORMAT_CODE_93 -> 4
        Barcode.FORMAT_CODABAR -> 8
        Barcode.FORMAT_DATA_MATRIX -> 16
        Barcode.FORMAT_EAN_13 -> 32
        Barcode.FORMAT_EAN_8 -> 64
        Barcode.FORMAT_ITF -> 128
        Barcode.FORMAT_QR_CODE -> 256
        Barcode.FORMAT_UPC_A -> 512
        Barcode.FORMAT_UPC_E -> 1024
        Barcode.FORMAT_PDF417 -> 2048
        Barcode.FORMAT_AZTEC -> 4096
        else -> -1
    }
}

internal fun dartFormatsToMlKit(formats: List<Int>?): IntArray? {
    if (formats.isNullOrEmpty()) {
        return null
    }

    return formats.map { raw ->
        when (raw) {
            -1 -> Barcode.FORMAT_UNKNOWN
            0 -> Barcode.FORMAT_ALL_FORMATS
            1 -> Barcode.FORMAT_CODE_128
            2 -> Barcode.FORMAT_CODE_39
            4 -> Barcode.FORMAT_CODE_93
            8 -> Barcode.FORMAT_CODABAR
            16 -> Barcode.FORMAT_DATA_MATRIX
            32 -> Barcode.FORMAT_EAN_13
            64 -> Barcode.FORMAT_EAN_8
            126, 127, 128 -> Barcode.FORMAT_ITF
            256 -> Barcode.FORMAT_QR_CODE
            512 -> Barcode.FORMAT_UPC_A
            1024 -> Barcode.FORMAT_UPC_E
            2048 -> Barcode.FORMAT_PDF417
            4096 -> Barcode.FORMAT_AZTEC
            else -> Barcode.FORMAT_UNKNOWN
        }
    }.toIntArray()
}
