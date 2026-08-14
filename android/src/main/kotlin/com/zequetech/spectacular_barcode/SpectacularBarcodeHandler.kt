package com.zequetech.spectacular_barcode

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry

internal class SpectacularBarcodeHandler(
    private val activity: Activity,
    private val barcodeEventHandler: BarcodeEventHandler,
    binaryMessenger: BinaryMessenger,
    private val permissions: CameraPermissions,
    private val addPermissionListener: (RequestPermissionsResultListener) -> Unit,
    textureRegistry: TextureRegistry,
) : MethodChannel.MethodCallHandler {
    private var methodChannel: MethodChannel? = null
    private var deviceOrientationChannel: EventChannel? = null
    private var deviceOrientationListener: DeviceOrientationListener? = null
    private var scanner: BarcodeScannerEngine? = null

    private val scannerCallback: ScannerCallback = { barcodes, image, width, height ->
        barcodeEventHandler.publishEvent(
            mapOf(
                "name" to "barcode",
                "data" to barcodes,
                "image" to mapOf(
                    "bytes" to image,
                    "width" to width?.toDouble(),
                    "height" to height?.toDouble(),
                ),
            ),
        )
    }

    private val errorCallback: ScannerErrorCallback = { error ->
        barcodeEventHandler.publishError(ErrorCodes.BARCODE_ERROR, error, null)
    }

    private val torchStateCallback: TorchStateCallback = { state ->
        barcodeEventHandler.publishEvent(
            mapOf(
                "name" to "torchState",
                "data" to state,
            ),
        )
    }

    private val zoomScaleStateCallback: ZoomScaleStateCallback = { zoomScale ->
        barcodeEventHandler.publishEvent(
            mapOf(
                "name" to "zoomScaleState",
                "data" to zoomScale,
            ),
        )
    }

    init {
        methodChannel = MethodChannel(
            binaryMessenger,
            "com.zequetech.spectacular_barcode/scanner/method",
        )
        methodChannel!!.setMethodCallHandler(this)

        deviceOrientationListener = DeviceOrientationListener(activity)
        deviceOrientationChannel = EventChannel(
            binaryMessenger,
            "com.zequetech.spectacular_barcode/scanner/deviceOrientation",
        )
        deviceOrientationChannel!!.setStreamHandler(deviceOrientationListener)

        scanner = BarcodeScannerEngine(
            activity,
            textureRegistry,
            scannerCallback,
            errorCallback,
            deviceOrientationListener!!,
        )
    }

    fun dispose(activityPluginBinding: ActivityPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        deviceOrientationChannel?.setStreamHandler(null)
        deviceOrientationChannel = null
        deviceOrientationListener?.stop()
        deviceOrientationListener = null
        barcodeEventHandler.dispose()
        scanner?.dispose()
        scanner = null

        permissions.getPermissionListener()?.let { listener ->
            activityPluginBinding.removeRequestPermissionsResultListener(listener)
        }
    }

    @ExperimentalGetImage
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "state" -> result.success(permissions.hasCameraPermission(activity))
            "request" -> permissions.requestPermission(
                activity,
                addPermissionListener,
                CameraPermissions.ResultCallback { errorCode ->
                    when (errorCode) {
                        null -> result.success(true)
                        ErrorCodes.CAMERA_ACCESS_DENIED -> result.success(false)
                        ErrorCodes.CAMERA_PERMISSIONS_REQUEST_ONGOING -> result.error(
                            ErrorCodes.CAMERA_PERMISSIONS_REQUEST_ONGOING,
                            ErrorCodes.CAMERA_PERMISSIONS_REQUEST_ONGOING_MESSAGE,
                            null,
                        )
                        else -> result.error(
                            ErrorCodes.GENERIC_ERROR,
                            ErrorCodes.GENERIC_ERROR_MESSAGE,
                            null,
                        )
                    }
                },
            )
            "start" -> start(call, result)
            "pause" -> pause(call, result)
            "stop" -> stop(call, result)
            "toggleTorch" -> {
                scanner?.toggleTorch()
                result.success(null)
            }
            "setScale" -> setScale(call, result)
            "resetScale" -> resetScale(result)
            "updateScanWindow" -> {
                scanner?.scanWindow = call.argument<List<Float>?>("rect")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    @ExperimentalGetImage
    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val torch = call.argument<Boolean>("torch") ?: false
        val facing = call.argument<Int>("facing") ?: 1
        val formats = call.argument<List<Int>>("formats")
        val returnImage = call.argument<Boolean>("returnImage") ?: false
        val speed = call.argument<Int>("speed") ?: 1
        val timeout = call.argument<Int>("timeout") ?: 250
        val cameraResolutionValues = call.argument<List<Int>>("cameraResolution")
        val initialZoom = call.argument<Double?>("initialZoom")

        val cameraResolution = if (cameraResolutionValues != null && cameraResolutionValues.size >= 2) {
            Size(cameraResolutionValues[0], cameraResolutionValues[1])
        } else {
            null
        }

        val detectionSpeed = when (speed) {
            0 -> DetectionSpeed.NO_DUPLICATES
            1 -> DetectionSpeed.NORMAL
            else -> DetectionSpeed.UNRESTRICTED
        }

        val cameraSelector = when (facing) {
            0 -> CameraSelector.DEFAULT_FRONT_CAMERA
            else -> CameraSelector.DEFAULT_BACK_CAMERA
        }

        val options = buildBarcodeScannerOptions(formats)

        scanner!!.start(
            options,
            returnImage,
            cameraSelector,
            torch,
            detectionSpeed,
            torchStateCallback,
            zoomScaleStateCallback,
            startedCallback = { params ->
                Handler(Looper.getMainLooper()).post {
                    result.success(
                        mapOf(
                            "textureId" to params.id,
                            "size" to mapOf(
                                "width" to params.width,
                                "height" to params.height,
                            ),
                            "currentTorchState" to params.currentTorchState,
                            "numberOfCameras" to params.numberOfCameras,
                            "cameraDirection" to params.cameraDirection,
                            "sensorOrientation" to params.sensorOrientation,
                            "handlesCropAndRotation" to params.handlesCropAndRotation,
                            "naturalDeviceOrientation" to params.naturalDeviceOrientation,
                        ),
                    )
                }
            },
            errorCallback = { error ->
                Handler(Looper.getMainLooper()).post {
                    when (error) {
                        is AlreadyStarted -> result.error(
                            ErrorCodes.ALREADY_STARTED,
                            ErrorCodes.ALREADY_STARTED_MESSAGE,
                            null,
                        )
                        is CameraError -> result.error(
                            ErrorCodes.CAMERA_ERROR,
                            ErrorCodes.CAMERA_ERROR_MESSAGE,
                            null,
                        )
                        is NoCamera -> result.error(
                            ErrorCodes.NO_CAMERA,
                            ErrorCodes.NO_CAMERA_MESSAGE,
                            null,
                        )
                        else -> result.error(
                            ErrorCodes.GENERIC_ERROR,
                            ErrorCodes.GENERIC_ERROR_MESSAGE,
                            null,
                        )
                    }
                }
            },
            timeout.toLong(),
            cameraResolution,
            initialZoom,
        )
    }

    private fun pause(call: MethodCall, result: MethodChannel.Result) {
        val force = call.argument<Boolean>("force") ?: false
        try {
            scanner!!.pause(force)
            result.success(null)
        } catch (error: Exception) {
            when (error) {
                is AlreadyPaused, is AlreadyStopped -> result.success(null)
                else -> throw error
            }
        }
    }

    private fun stop(call: MethodCall, result: MethodChannel.Result) {
        val force = call.argument<Boolean>("force") ?: false
        try {
            scanner!!.stop(force)
            result.success(null)
        } catch (_: AlreadyStopped) {
            result.success(null)
        }
    }

    private fun setScale(call: MethodCall, result: MethodChannel.Result) {
        try {
            scanner!!.setScale(call.arguments as Double)
            result.success(null)
        } catch (_: ZoomWhenStopped) {
            result.error(
                ErrorCodes.SET_SCALE_WHEN_STOPPED,
                ErrorCodes.SET_SCALE_WHEN_STOPPED_MESSAGE,
                null,
            )
        } catch (_: ZoomNotInRange) {
            result.error(
                ErrorCodes.GENERIC_ERROR,
                ErrorCodes.INVALID_ZOOM_SCALE_MESSAGE,
                null,
            )
        }
    }

    private fun resetScale(result: MethodChannel.Result) {
        try {
            scanner!!.resetScale()
            result.success(null)
        } catch (_: ZoomWhenStopped) {
            result.error(
                ErrorCodes.SET_SCALE_WHEN_STOPPED,
                ErrorCodes.SET_SCALE_WHEN_STOPPED_MESSAGE,
                null,
            )
        }
    }

    private fun buildBarcodeScannerOptions(formats: List<Int>?): BarcodeScannerOptions? {
        val mlFormats = dartFormatsToMlKit(formats) ?: return null

        return if (mlFormats.size == 1) {
            BarcodeScannerOptions.Builder().setBarcodeFormats(mlFormats.first()).build()
        } else {
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(
                    mlFormats.first(),
                    *mlFormats.copyOfRange(1, mlFormats.size),
                )
                .build()
        }
    }
}
