import 'dart:ui';

import 'package:spectacular_barcode/src/enums/camera_facing.dart';
import 'package:spectacular_barcode/src/enums/torch_state.dart';

/// Attributes returned by the native `start` method.
class ViewAttributes {
  const ViewAttributes({
    required this.cameraDirection,
    required this.currentTorchMode,
    required this.size,
    this.numberOfCameras,
  });

  final CameraFacing cameraDirection;
  final TorchState currentTorchMode;
  final int? numberOfCameras;
  final Size size;
}
