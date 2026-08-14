import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:spectacular_barcode/src/enums/camera_facing.dart';

/// Rotates the camera [Texture] to match device/sensor orientation.
class RotatedPreview extends StatefulWidget {
  const RotatedPreview({
    required this.child,
    required this.deviceOrientationStream,
    required this.facingSign,
    required this.initialDeviceOrientation,
    required this.sensorOrientationDegrees,
    super.key,
  });

  factory RotatedPreview.fromCameraDirection(
    CameraFacing cameraFacingDirection, {
    required Widget child,
    required Stream<DeviceOrientation> deviceOrientationStream,
    required DeviceOrientation initialDeviceOrientation,
    required double sensorOrientationDegrees,
    Key? key,
  }) {
    final facingSign = switch (cameraFacingDirection) {
      CameraFacing.front => 1,
      CameraFacing.back => -1,
      CameraFacing.unknown => 1,
      CameraFacing.external => 1,
    };

    return RotatedPreview(
      deviceOrientationStream: deviceOrientationStream,
      facingSign: facingSign,
      initialDeviceOrientation: initialDeviceOrientation,
      sensorOrientationDegrees: sensorOrientationDegrees,
      key: key,
      child: child,
    );
  }

  final Widget child;
  final Stream<DeviceOrientation> deviceOrientationStream;
  final int facingSign;
  final DeviceOrientation initialDeviceOrientation;
  final double sensorOrientationDegrees;

  @override
  State<RotatedPreview> createState() => _RotatedPreviewState();
}

class _RotatedPreviewState extends State<RotatedPreview> {
  late DeviceOrientation deviceOrientation = widget.initialDeviceOrientation;
  StreamSubscription<DeviceOrientation>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.deviceOrientationStream.listen((orientation) {
      if (!mounted) {
        return;
      }
      setState(() {
        deviceOrientation = orientation;
      });
    });
  }

  double _computeRotationDegrees(
    DeviceOrientation orientation, {
    required double sensorOrientationDegrees,
    required int sign,
  }) {
    final deviceOrientationDegrees = switch (orientation) {
      DeviceOrientation.portraitUp => 0.0,
      DeviceOrientation.landscapeRight => 90.0,
      DeviceOrientation.portraitDown => 180.0,
      DeviceOrientation.landscapeLeft => 270.0,
    };

    var rotationDegrees =
        (sensorOrientationDegrees - deviceOrientationDegrees * sign + 360) %
            360;
    rotationDegrees -= deviceOrientationDegrees;
    return rotationDegrees;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rotationDegrees = _computeRotationDegrees(
      deviceOrientation,
      sensorOrientationDegrees: widget.sensorOrientationDegrees,
      sign: widget.facingSign,
    );
    return RotatedBox(
      quarterTurns: ((rotationDegrees / 90).round() % 4 + 4) % 4,
      child: widget.child,
    );
  }
}
