import 'dart:ui';

import 'package:spectacular_barcode/src/enums/camera_facing.dart';
import 'package:spectacular_barcode/src/enums/error_code.dart';
import 'package:spectacular_barcode/src/enums/torch_state.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_exception.dart';

/// Current state of [SpectacularBarcodeController].
class ScannerState {
  const ScannerState({
    required this.availableCameras,
    required this.cameraDirection,
    required this.isInitialized,
    required this.isStarting,
    required this.isRunning,
    required this.size,
    required this.torchState,
    required this.zoomScale,
    this.error,
  });

  const ScannerState.uninitialized()
      : this(
          availableCameras: null,
          cameraDirection: CameraFacing.unknown,
          isInitialized: false,
          isStarting: false,
          isRunning: false,
          size: Size.zero,
          torchState: TorchState.unavailable,
          zoomScale: 1,
        );

  final int? availableCameras;
  final CameraFacing cameraDirection;
  final SpectacularBarcodeException? error;
  final bool isInitialized;
  final bool isStarting;
  final bool isRunning;
  final Size size;
  final TorchState torchState;
  final double zoomScale;

  bool get hasCameraPermission {
    return isInitialized &&
        error?.errorCode != SpectacularBarcodeErrorCode.permissionDenied;
  }

  ScannerState copyWith({
    int? availableCameras,
    CameraFacing? cameraDirection,
    SpectacularBarcodeException? error,
    bool clearError = false,
    bool? isInitialized,
    bool? isStarting,
    bool? isRunning,
    Size? size,
    TorchState? torchState,
    double? zoomScale,
  }) {
    return ScannerState(
      availableCameras: availableCameras ?? this.availableCameras,
      cameraDirection: cameraDirection ?? this.cameraDirection,
      error: clearError ? null : (error ?? this.error),
      isInitialized: isInitialized ?? this.isInitialized,
      isStarting: isStarting ?? this.isStarting,
      isRunning: isRunning ?? this.isRunning,
      size: size ?? this.size,
      torchState: torchState ?? this.torchState,
      zoomScale: zoomScale ?? this.zoomScale,
    );
  }
}
