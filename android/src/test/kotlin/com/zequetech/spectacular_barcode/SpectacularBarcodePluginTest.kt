package com.zequetech.spectacular_barcode

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class SpectacularBarcodePluginTest {
    @Test
    fun dartFormatsToMlKit_mapsKnownFormats() {
        val formats = dartFormatsToMlKit(listOf(256, 32, 1))
        requireNotNull(formats)
        assertEquals(3, formats.size)
        assertTrue(formats.contains(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_QR_CODE))
        assertTrue(formats.contains(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_EAN_13))
        assertTrue(formats.contains(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_CODE_128))
    }

    @Test
    fun dartFormatsToMlKit_returnsNullForEmpty() {
        assertEquals(null, dartFormatsToMlKit(null))
        assertEquals(null, dartFormatsToMlKit(emptyList()))
    }

    @Test
    fun errorCodes_areStable() {
        assertEquals("SPECTACULAR_BARCODE_ALREADY_STARTED_ERROR", ErrorCodes.ALREADY_STARTED)
        assertFalse(ErrorCodes.NO_CAMERA_MESSAGE.isBlank())
    }
}
