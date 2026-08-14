import 'package:flutter/services.dart';
import 'package:spectacular_barcode/src/enums/camera_facing.dart';

/// Android SurfaceProducer orientation metadata for preview correction.
class AndroidSurfaceProducerDelegate {
  AndroidSurfaceProducerDelegate({
    required this.cameraFacingDirection,
    required this.handlesCropAndRotation,
    required this.initialDeviceOrientation,
    required this.sensorOrientationDegrees,
  });

  factory AndroidSurfaceProducerDelegate.fromConfiguration(
    Map<Object?, Object?> config,
    CameraFacing cameraDirection,
  ) {
    final handlesCropAndRotation =
        config['handlesCropAndRotation'] as bool? ?? true;
    final sensorOrientation =
        (config['sensorOrientation'] as num?)?.toDouble() ?? 90;
    final natural = config['naturalDeviceOrientation'] as String?;

    return AndroidSurfaceProducerDelegate(
      cameraFacingDirection: cameraDirection,
      handlesCropAndRotation: handlesCropAndRotation,
      initialDeviceOrientation: _parseOrientation(natural),
      sensorOrientationDegrees: sensorOrientation,
    );
  }

  final CameraFacing cameraFacingDirection;
  final bool handlesCropAndRotation;
  final DeviceOrientation initialDeviceOrientation;
  final double sensorOrientationDegrees;
}

DeviceOrientation _parseOrientation(String? value) {
  switch (value) {
    case 'PORTRAIT_DOWN':
      return DeviceOrientation.portraitDown;
    case 'LANDSCAPE_LEFT':
      return DeviceOrientation.landscapeLeft;
    case 'LANDSCAPE_RIGHT':
      return DeviceOrientation.landscapeRight;
    case 'PORTRAIT_UP':
    default:
      return DeviceOrientation.portraitUp;
  }
}
