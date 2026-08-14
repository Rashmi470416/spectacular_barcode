package com.zequetech.spectacular_barcode

import android.app.Activity
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.Surface
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.core.TorchState
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executors
import kotlin.math.roundToInt

internal typealias ScannerCallback =
    (barcodes: List<Map<String, Any?>>, image: ByteArray?, width: Int?, height: Int?) -> Unit
internal typealias ScannerErrorCallback = (error: String) -> Unit
internal typealias TorchStateCallback = (state: Int) -> Unit
internal typealias ZoomScaleStateCallback = (zoomScale: Double) -> Unit
internal typealias StartedCallback = (parameters: StartParameters) -> Unit

internal class BarcodeScannerEngine(
    private val activity: Activity,
    private val textureRegistry: TextureRegistry,
    private val scannerCallback: ScannerCallback,
    private val scannerErrorCallback: ScannerErrorCallback,
    private val deviceOrientationListener: DeviceOrientationListener,
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var scanner: BarcodeScanner? = null
    private var lastScanned: List<String?>? = null
    private var scannerTimeout = false
    private var imageAnalysis: ImageAnalysis? = null
    private var analysisExecutor = Executors.newSingleThreadExecutor()

    var scanWindow: List<Float>? = null
    private var detectionSpeed: DetectionSpeed = DetectionSpeed.NORMAL
    private var detectionTimeout: Long = 250
    private var isPaused = false

    @ExperimentalGetImage
    private val captureOutput = ImageAnalysis.Analyzer { imageProxy ->
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return@Analyzer
        }

        if (detectionSpeed == DetectionSpeed.NORMAL && scannerTimeout) {
            imageProxy.close()
            return@Analyzer
        } else if (detectionSpeed == DetectionSpeed.NORMAL) {
            scannerTimeout = true
        }

        val inputImage = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees,
        )

        val activeScanner = scanner
        if (activeScanner == null) {
            imageProxy.close()
            return@Analyzer
        }

        activeScanner.process(inputImage)
            .addOnSuccessListener { barcodes ->
                if (detectionSpeed == DetectionSpeed.NO_DUPLICATES) {
                    val newScanned = barcodes.mapNotNull { barcode -> barcode.rawValue }.sorted()
                    if (newScanned == lastScanned) {
                        imageProxy.close()
                        return@addOnSuccessListener
                    }
                    if (newScanned.isNotEmpty()) {
                        lastScanned = newScanned
                    }
                }

                val barcodeMap = mutableListOf<Map<String, Any?>>()
                for (barcode in barcodes) {
                    val window = scanWindow
                    if (window == null || isBarcodeInScanWindow(window, barcode, imageProxy)) {
                        barcodeMap.add(barcode.data)
                    }
                }

                if (barcodeMap.isEmpty()) {
                    imageProxy.close()
                    return@addOnSuccessListener
                }

                val portrait = (camera?.cameraInfo?.sensorRotationDegrees ?: 0) % 180 == 0
                scannerCallback(
                    barcodeMap,
                    null,
                    if (portrait) inputImage.width else inputImage.height,
                    if (portrait) inputImage.height else inputImage.width,
                )
                imageProxy.close()
            }
            .addOnFailureListener { error ->
                scannerErrorCallback(error.localizedMessage ?: error.toString())
                imageProxy.close()
            }

        if (detectionSpeed == DetectionSpeed.NORMAL) {
            Handler(Looper.getMainLooper()).postDelayed({
                scannerTimeout = false
            }, detectionTimeout)
        }
    }

    private fun createSurfaceProvider(
        surfaceProducer: TextureRegistry.SurfaceProducer,
    ): Preview.SurfaceProvider {
        return Preview.SurfaceProvider { request: SurfaceRequest ->
            surfaceProducer.setCallback(
                object : TextureRegistry.SurfaceProducer.Callback {
                    override fun onSurfaceAvailable() {}

                    override fun onSurfaceCleanup() {
                        request.invalidate()
                    }
                },
            )

            surfaceProducer.setSize(request.resolution.width, request.resolution.height)
            val surface: Surface = surfaceProducer.surface

            request.provideSurface(surface, Executors.newSingleThreadExecutor()) {
                surface.release()
            }
        }
    }

    fun isBarcodeInScanWindow(
        scanWindow: List<Float>,
        barcode: Barcode,
        inputImage: ImageProxy,
    ): Boolean {
        val cornerPoints = barcode.cornerPoints ?: return false

        return try {
            val rotationDegrees = inputImage.imageInfo.rotationDegrees
            val imageWidth =
                if (rotationDegrees % 180 == 0) inputImage.width else inputImage.height
            val imageHeight =
                if (rotationDegrees % 180 == 0) inputImage.height else inputImage.width

            val left = (scanWindow[0] * imageWidth).roundToInt()
            val top = (scanWindow[1] * imageHeight).roundToInt()
            val right = (scanWindow[2] * imageWidth).roundToInt()
            val bottom = (scanWindow[3] * imageHeight).roundToInt()
            val scaled = Rect(left, top, right, bottom)

            cornerPoints.all { scaled.contains(it.x, it.y) }
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    @ExperimentalGetImage
    fun start(
        barcodeScannerOptions: BarcodeScannerOptions?,
        @Suppress("UNUSED_PARAMETER") returnImage: Boolean,
        cameraPosition: CameraSelector,
        torch: Boolean,
        detectionSpeed: DetectionSpeed,
        torchStateCallback: TorchStateCallback,
        zoomScaleStateCallback: ZoomScaleStateCallback,
        startedCallback: StartedCallback,
        errorCallback: (Exception) -> Unit,
        detectionTimeout: Long,
        cameraResolutionWanted: Size?,
        initialZoom: Double?,
    ) {
        this.detectionSpeed = detectionSpeed
        this.detectionTimeout = detectionTimeout
        isPaused = false

        if (camera?.cameraInfo != null && preview != null && surfaceProducer != null) {
            errorCallback(AlreadyStarted())
            return
        }

        lastScanned = null
        scanner = if (barcodeScannerOptions == null) {
            BarcodeScanning.getClient()
        } else {
            BarcodeScanning.getClient(barcodeScannerOptions)
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        val mainExecutor = ContextCompat.getMainExecutor(activity)

        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
            } catch (_: Exception) {
                errorCallback(CameraError())
                return@addListener
            }

            val provider = cameraProvider
            if (provider == null) {
                errorCallback(CameraError())
                return@addListener
            }

            val numberOfCameras = provider.availableCameraInfos.size
            provider.unbindAll()

            surfaceProducer = surfaceProducer ?: textureRegistry.createSurfaceProducer()
            val surfaceProvider = createSurfaceProvider(surfaceProducer!!)

            // Do not set Preview targetRotation — SurfaceProducer/Flutter handle
            // preview orientation. Only ImageAnalysis needs display rotation.
            preview = Preview.Builder()
                .build()
                .apply { setSurfaceProvider(surfaceProvider) }

            val cameraResolution = cameraResolutionWanted ?: Size(1920, 1080)
            val resolutionSelector = ResolutionSelector.Builder()
                .setResolutionStrategy(
                    ResolutionStrategy(
                        cameraResolution,
                        ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                    ),
                )
                .build()

            val displayRotation = deviceOrientationListener.getDisplay().rotation
            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
                .setResolutionSelector(resolutionSelector)
                .setTargetRotation(displayRotation)
                .build()
                .apply { setAnalyzer(analysisExecutor, captureOutput) }
            imageAnalysis = analysis

            deviceOrientationListener.onDisplayRotationChanged = { rotation ->
                imageAnalysis?.targetRotation = rotation
            }

            try {
                camera = provider.bindToLifecycle(
                    activity as LifecycleOwner,
                    cameraPosition,
                    preview,
                    analysis,
                )
            } catch (_: Exception) {
                errorCallback(NoCamera())
                return@addListener
            }

            camera?.let { cam ->
                cam.cameraInfo.torchState.observe(activity as LifecycleOwner) { state ->
                    torchStateCallback(state)
                }
                cam.cameraInfo.zoomState.observe(activity) { state ->
                    zoomScaleStateCallback(state.linearZoom.toDouble())
                }

                if (cam.cameraInfo.hasFlashUnit()) {
                    cam.cameraControl.enableTorch(torch)
                }

                if (initialZoom != null) {
                    try {
                        if (initialZoom in 0.0..1.0) {
                            cam.cameraControl.setLinearZoom(initialZoom.toFloat())
                        } else {
                            cam.cameraControl.setZoomRatio(initialZoom.toFloat())
                        }
                    } catch (_: Exception) {
                        errorCallback(ZoomNotInRange())
                        return@addListener
                    }
                }
            }

            val resolution = analysis.resolutionInfo?.resolution
                ?: preview?.resolutionInfo?.resolution
                ?: cameraResolution

            val width = resolution.width.toDouble()
            val height = resolution.height.toDouble()
            val sensorRotationDegrees = camera?.cameraInfo?.sensorRotationDegrees ?: 0
            val portrait = sensorRotationDegrees % 180 == 0
            val cameraDirection = when (camera?.cameraInfo?.lensFacing) {
                CameraSelector.LENS_FACING_FRONT -> 0
                CameraSelector.LENS_FACING_BACK -> 1
                CameraSelector.LENS_FACING_EXTERNAL -> 2
                else -> null
            }

            var currentTorchState = -1
            camera?.cameraInfo?.let { info ->
                if (info.hasFlashUnit()) {
                    currentTorchState = info.torchState.value ?: -1
                }
            }

            deviceOrientationListener.start()

            startedCallback(
                StartParameters(
                    width = if (portrait) width else height,
                    height = if (portrait) height else width,
                    currentTorchState = currentTorchState,
                    id = surfaceProducer!!.id(),
                    numberOfCameras = numberOfCameras,
                    cameraDirection = cameraDirection,
                    sensorOrientation = sensorRotationDegrees,
                    handlesCropAndRotation = surfaceProducer!!.handlesCropAndRotation(),
                    naturalDeviceOrientation = deviceOrientationListener.getOrientation(),
                ),
            )
        }, mainExecutor)
    }

    fun pause(force: Boolean = false) {
        if (!force) {
            if (isPaused) {
                throw AlreadyPaused()
            } else if (isStopped()) {
                throw AlreadyStopped()
            }
        }
        deviceOrientationListener.stop()
        cameraProvider?.unbindAll()
        isPaused = true
    }

    fun stop(force: Boolean = false) {
        if (!force) {
            if (!isPaused && isStopped()) {
                throw AlreadyStopped()
            }
        }
        deviceOrientationListener.stop()
        releaseCamera()
    }

    private fun releaseCamera() {
        val owner = activity as LifecycleOwner
        camera?.cameraInfo?.let {
            it.torchState.removeObservers(owner)
            it.zoomState.removeObservers(owner)
        }

        cameraProvider?.unbindAll()
        imageAnalysis = null
        preview = null
        camera = null

        surfaceProducer?.release()
        surfaceProducer = null

        scanner?.close()
        scanner = null
        lastScanned = null
        isPaused = false

        analysisExecutor.shutdown()
        analysisExecutor = Executors.newSingleThreadExecutor()
    }

    private fun isStopped() = camera == null && preview == null

    fun toggleTorch() {
        val cam = camera ?: return
        if (!cam.cameraInfo.hasFlashUnit()) {
            return
        }
        when (cam.cameraInfo.torchState.value) {
            TorchState.OFF -> cam.cameraControl.enableTorch(true)
            TorchState.ON -> cam.cameraControl.enableTorch(false)
        }
    }

    fun setScale(scale: Double) {
        if (scale > 1.0 || scale < 0) {
            throw ZoomNotInRange()
        }
        if (camera == null) {
            throw ZoomWhenStopped()
        }
        camera?.cameraControl?.setLinearZoom(scale.toFloat())
    }

    fun resetScale() {
        if (camera == null) {
            throw ZoomWhenStopped()
        }
        camera?.cameraControl?.setZoomRatio(1f)
    }

    fun dispose() {
        if (!isStopped()) {
            stop(force = true)
        }
    }
}
