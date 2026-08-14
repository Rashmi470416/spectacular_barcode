import 'dart:ui';

import 'package:spectacular_barcode/src/enums/barcode_format.dart';
import 'package:spectacular_barcode/src/enums/camera_facing.dart';
import 'package:spectacular_barcode/src/enums/detection_speed.dart';

/// Options passed to the native `start` method.
class StartOptions {
  const StartOptions({
    required this.cameraDirection,
    required this.detectionSpeed,
    required this.detectionTimeoutMs,
    required this.formats,
    required this.returnImage,
    required this.torchEnabled,
    this.cameraResolution,
    this.initialZoom,
  });

  final CameraFacing cameraDirection;
  final Size? cameraResolution;
  final DetectionSpeed detectionSpeed;
  final int detectionTimeoutMs;
  final List<BarcodeFormat> formats;
  final bool returnImage;
  final bool torchEnabled;
  final double? initialZoom;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (cameraResolution != null)
        'cameraResolution': <int>[
          cameraResolution!.width.toInt(),
          cameraResolution!.height.toInt(),
        ],
      'facing': cameraDirection.rawValue,
      if (formats.isNotEmpty)
        'formats': formats.map((format) => format.rawValue).toList(),
      'returnImage': returnImage,
      'speed': detectionSpeed.rawValue,
      'timeout': detectionTimeoutMs,
      'torch': torchEnabled,
      'initialZoom': initialZoom,
    };
  }
}
