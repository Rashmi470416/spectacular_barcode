package com.zequetech.spectacular_barcode

internal data class StartParameters(
    val width: Double,
    val height: Double,
    val currentTorchState: Int,
    val id: Long,
    val numberOfCameras: Int,
    val cameraDirection: Int?,
    val sensorOrientation: Int,
    val handlesCropAndRotation: Boolean,
    val naturalDeviceOrientation: String,
)
