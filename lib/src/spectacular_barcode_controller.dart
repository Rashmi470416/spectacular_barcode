import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:spectacular_barcode/src/enums/barcode_format.dart';
import 'package:spectacular_barcode/src/enums/camera_facing.dart';
import 'package:spectacular_barcode/src/enums/detection_speed.dart';
import 'package:spectacular_barcode/src/enums/error_code.dart';
import 'package:spectacular_barcode/src/enums/torch_state.dart';
import 'package:spectacular_barcode/src/objects/barcode_capture.dart';
import 'package:spectacular_barcode/src/objects/scanner_state.dart';
import 'package:spectacular_barcode/src/objects/start_options.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_exception.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_platform_interface.dart';

/// Controller for [SpectacularBarcodeView].
class SpectacularBarcodeController extends ValueNotifier<ScannerState> {
  SpectacularBarcodeController({
    this.autoStart = true,
    this.cameraResolution,
    this.detectionSpeed = DetectionSpeed.normal,
    int detectionTimeoutMs = 250,
    this.facing = CameraFacing.back,
    this.formats = const <BarcodeFormat>[],
    this.returnImage = false,
    this.torchEnabled = false,
    this.initialZoom,
  })  : detectionTimeoutMs =
            detectionSpeed == DetectionSpeed.normal ? detectionTimeoutMs : 0,
        assert(
          facing != CameraFacing.unknown,
          'CameraFacing.unknown is not a valid camera direction.',
        ),
        super(const ScannerState.uninitialized());

  final bool autoStart;
  final Size? cameraResolution;
  final DetectionSpeed detectionSpeed;
  final int detectionTimeoutMs;
  final CameraFacing facing;
  final List<BarcodeFormat> formats;
  final bool returnImage;
  final bool torchEnabled;
  final double? initialZoom;

  final StreamController<BarcodeCapture> _barcodesController =
      StreamController.broadcast();

  Stream<BarcodeCapture> get barcodes => _barcodesController.stream;

  StreamSubscription<BarcodeCapture?>? _barcodesSubscription;
  StreamSubscription<TorchState>? _torchStateSubscription;
  StreamSubscription<double>? _zoomScaleSubscription;

  bool _isDisposed = false;
  final Completer<void> _isAttachedCompleter = Completer<void>();

  void attach() {
    if (!_isAttachedCompleter.isCompleted) {
      _isAttachedCompleter.complete();
    }
  }

  void _disposeListeners() {
    unawaited(_barcodesSubscription?.cancel());
    unawaited(_torchStateSubscription?.cancel());
    unawaited(_zoomScaleSubscription?.cancel());
    _barcodesSubscription = null;
    _torchStateSubscription = null;
    _zoomScaleSubscription = null;
  }

  void _setupListeners() {
    _disposeListeners();

    _barcodesSubscription =
        SpectacularBarcodePlatform.instance.barcodesStream.listen(
      (barcode) {
        if (_barcodesController.isClosed || barcode == null) {
          return;
        }
        _barcodesController.add(barcode);
      },
      onError: (Object error) {
        if (!_barcodesController.isClosed) {
          _barcodesController.addError(error);
        }
      },
      cancelOnError: false,
    );

    _torchStateSubscription =
        SpectacularBarcodePlatform.instance.torchStateStream.listen((state) {
      if (!_isDisposed) {
        value = value.copyWith(torchState: state);
      }
    });

    _zoomScaleSubscription =
        SpectacularBarcodePlatform.instance.zoomScaleStateStream.listen((
      zoomScale,
    ) {
      if (!_isDisposed) {
        value = value.copyWith(zoomScale: zoomScale);
      }
    });
  }

  void _throwIfNotInitialized() {
    if (_isDisposed) {
      throw const SpectacularBarcodeException(
        errorCode: SpectacularBarcodeErrorCode.controllerDisposed,
      );
    }
    if (!value.isInitialized) {
      throw const SpectacularBarcodeException(
        errorCode: SpectacularBarcodeErrorCode.controllerUninitialized,
      );
    }
  }

  bool _markStopped() {
    if (!value.isInitialized || !value.isRunning || _isDisposed) {
      return false;
    }

    _disposeListeners();

    final oldTorchState = value.torchState;
    value = value.copyWith(
      isRunning: false,
      torchState: oldTorchState == TorchState.unavailable
          ? TorchState.unavailable
          : TorchState.off,
    );
    return true;
  }

  Widget buildCameraView() {
    _throwIfNotInitialized();
    return SpectacularBarcodePlatform.instance.buildCameraView();
  }

  Future<void> resetZoomScale() async {
    _throwIfNotInitialized();
    if (!value.isRunning) {
      return;
    }
    await SpectacularBarcodePlatform.instance.resetZoomScale();
  }

  Future<void> setZoomScale(double zoomScale) async {
    _throwIfNotInitialized();
    if (!value.isRunning) {
      return;
    }
    await SpectacularBarcodePlatform.instance.setZoomScale(
      zoomScale.clamp(0.0, 1.0),
    );
  }

  Future<void> updateScanWindow(Rect? window) async {
    _throwIfNotInitialized();
    await SpectacularBarcodePlatform.instance.updateScanWindow(window);
  }

  Future<void> start({CameraFacing? cameraDirection}) async {
    if (_isDisposed) {
      throw const SpectacularBarcodeException(
        errorCode: SpectacularBarcodeErrorCode.controllerDisposed,
      );
    }

    if (!_isAttachedCompleter.isCompleted) {
      await _isAttachedCompleter.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {
          throw const SpectacularBarcodeException(
            errorCode: SpectacularBarcodeErrorCode.genericError,
            errorDetails: SpectacularBarcodeErrorDetails(
              message: 'Controller was not attached to a widget.',
            ),
          );
        },
      );
    }

    if (value.isRunning) {
      return;
    }

    if (value.isStarting) {
      throw const SpectacularBarcodeException(
        errorCode: SpectacularBarcodeErrorCode.controllerInitializing,
      );
    }

    value = value.copyWith(isStarting: true, clearError: true);

    final options = StartOptions(
      cameraDirection: cameraDirection ?? facing,
      cameraResolution: cameraResolution,
      detectionSpeed: detectionSpeed,
      detectionTimeoutMs: detectionTimeoutMs,
      formats: formats,
      returnImage: returnImage,
      torchEnabled: torchEnabled,
      initialZoom: initialZoom,
    );

    try {
      _setupListeners();
      final viewAttributes =
          await SpectacularBarcodePlatform.instance.start(options);

      if (!_isDisposed) {
        value = value.copyWith(
          availableCameras: viewAttributes.numberOfCameras,
          cameraDirection: viewAttributes.cameraDirection,
          isInitialized: true,
          isStarting: false,
          isRunning: true,
          size: viewAttributes.size,
          torchState: viewAttributes.currentTorchMode,
          clearError: true,
        );
      }
    } on SpectacularBarcodeException catch (error) {
      if (!_isDisposed) {
        value = value.copyWith(
          cameraDirection: CameraFacing.unknown,
          isInitialized: true,
          isStarting: false,
          isRunning: false,
          error: error,
          size: Size.zero,
          torchState: TorchState.unavailable,
          zoomScale: 1,
        );
      }
    }
  }

  Future<void> stop() async {
    if (_markStopped()) {
      await SpectacularBarcodePlatform.instance.stop();
    }
  }

  Future<void> pause() async {
    if (_markStopped()) {
      await SpectacularBarcodePlatform.instance.pause();
    }
  }

  Future<void> toggleTorch() async {
    _throwIfNotInitialized();
    if (!value.isRunning) {
      return;
    }
    await SpectacularBarcodePlatform.instance.toggleTorch();
  }

  Future<void> switchCamera() async {
    _throwIfNotInitialized();
    final nextFacing = value.cameraDirection == CameraFacing.front
        ? CameraFacing.back
        : CameraFacing.front;
    await stop();
    await start(cameraDirection: nextFacing);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _disposeListeners();
    await _barcodesController.close();
    await SpectacularBarcodePlatform.instance.dispose();
    super.dispose();
  }
}
