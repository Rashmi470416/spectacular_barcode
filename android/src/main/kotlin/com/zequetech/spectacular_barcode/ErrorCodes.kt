package com.zequetech.spectacular_barcode

internal object ErrorCodes {
    const val ALREADY_STARTED = "SPECTACULAR_BARCODE_ALREADY_STARTED_ERROR"
    const val ALREADY_STARTED_MESSAGE = "The scanner was already started."
    const val BARCODE_ERROR = "SPECTACULAR_BARCODE_BARCODE_ERROR"
    const val CAMERA_ACCESS_DENIED = "SPECTACULAR_BARCODE_CAMERA_PERMISSION_DENIED"
    const val CAMERA_ERROR = "SPECTACULAR_BARCODE_CAMERA_ERROR"
    const val CAMERA_ERROR_MESSAGE = "An error occurred when opening the camera."
    const val CAMERA_PERMISSIONS_REQUEST_ONGOING =
        "SPECTACULAR_BARCODE_CAMERA_PERMISSION_REQUEST_PENDING"
    const val CAMERA_PERMISSIONS_REQUEST_ONGOING_MESSAGE =
        "Another request is ongoing and multiple requests cannot be handled at once."
    const val GENERIC_ERROR = "SPECTACULAR_BARCODE_GENERIC_ERROR"
    const val GENERIC_ERROR_MESSAGE = "An unknown error occurred."
    const val INVALID_ZOOM_SCALE_MESSAGE =
        "The zoom scale should be between 0 and 1 (both inclusive)"
    const val NO_CAMERA = "SPECTACULAR_BARCODE_NO_CAMERA_ERROR"
    const val NO_CAMERA_MESSAGE = "No cameras available."
    const val SET_SCALE_WHEN_STOPPED = "SPECTACULAR_BARCODE_SET_SCALE_WHEN_STOPPED_ERROR"
    const val SET_SCALE_WHEN_STOPPED_MESSAGE =
        "The zoom scale cannot be changed when the camera is stopped."
}
