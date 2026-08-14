import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:spectacular_barcode/src/enums/authorization_state.dart';
import 'package:spectacular_barcode/src/enums/camera_facing.dart';
import 'package:spectacular_barcode/src/enums/error_code.dart';
import 'package:spectacular_barcode/src/enums/torch_state.dart';
import 'package:spectacular_barcode/src/method_channel/android_surface_producer_delegate.dart';
import 'package:spectacular_barcode/src/method_channel/rotated_preview.dart';
import 'package:spectacular_barcode/src/objects/barcode.dart';
import 'package:spectacular_barcode/src/objects/barcode_capture.dart';
import 'package:spectacular_barcode/src/objects/start_options.dart';
import 'package:spectacular_barcode/src/objects/view_attributes.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_exception.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_platform_interface.dart';

/// MethodChannel + EventChannel implementation of [SpectacularBarcodePlatform].
class MethodChannelSpectacularBarcode extends SpectacularBarcodePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'com.zequetech.spectacular_barcode/scanner/method',
  );

  @visibleForTesting
  final eventChannel = const EventChannel(
    'com.zequetech.spectacular_barcode/scanner/event',
  );

  @visibleForTesting
  final deviceOrientationEventChannel = const EventChannel(
    'com.zequetech.spectacular_barcode/scanner/deviceOrientation',
  );

  Stream<Map<Object?, Object?>>? _eventsStream;
  Stream<DeviceOrientation>? _deviceOrientationStream;
  AndroidSurfaceProducerDelegate? _surfaceProducerDelegate;
  int? _textureId;
  bool _pausing = false;

  Stream<Map<Object?, Object?>> get eventsStream {
    _eventsStream ??=
        eventChannel.receiveBroadcastStream().cast<Map<Object?, Object?>>();
    return _eventsStream!;
  }

  Stream<DeviceOrientation> get deviceOrientationChangedStream {
    _deviceOrientationStream ??= deviceOrientationEventChannel
        .receiveBroadcastStream()
        .cast<String>()
        .map(_parseOrientation);
    return _deviceOrientationStream!;
  }

  DeviceOrientation _parseOrientation(String value) {
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

  BarcodeCapture? _parseBarcode(Map<Object?, Object?>? event) {
    if (event == null) {
      return null;
    }

    final data = event['data'];
    if (data is! List<Object?>) {
      return null;
    }

    final barcodes = data.cast<Map<Object?, Object?>>();
    final imageData = event['image'] as Map<Object?, Object?>?;
    final image = imageData?['bytes'] as Uint8List?;
    final width = (imageData?['width'] as num?)?.toDouble();
    final height = (imageData?['height'] as num?)?.toDouble();

    return BarcodeCapture(
      raw: event,
      barcodes: barcodes.map(Barcode.fromNative).toList(),
      image: image,
      size: width == null || height == null ? Size.zero : Size(width, height),
    );
  }

  Future<void> _requestCameraPermission() async {
    try {
      final authorizationState = AuthorizationState.fromRawValue(
        await methodChannel.invokeMethod<int>('state') ?? 0,
      );

      switch (authorizationState) {
        case AuthorizationState.authorized:
          return;
        case AuthorizationState.denied:
        case AuthorizationState.undetermined:
          final granted =
              await methodChannel.invokeMethod<bool>('request') ?? false;
          if (!granted) {
            throw const SpectacularBarcodeException(
              errorCode: SpectacularBarcodeErrorCode.permissionDenied,
            );
          }
      }
    } on PlatformException catch (error) {
      throw SpectacularBarcodeException(
        errorCode: SpectacularBarcodeErrorCode.genericError,
        errorDetails: SpectacularBarcodeErrorDetails(
          code: error.code,
          details: error.details,
          message: error.message,
        ),
      );
    }
  }

  SpectacularBarcodeErrorCode _mapPlatformError(PlatformException error) {
    switch (error.code) {
      case 'SPECTACULAR_BARCODE_ALREADY_STARTED_ERROR':
        return SpectacularBarcodeErrorCode.controllerAlreadyInitialized;
      case 'SPECTACULAR_BARCODE_CAMERA_ERROR':
        return SpectacularBarcodeErrorCode.cameraError;
      case 'SPECTACULAR_BARCODE_NO_CAMERA_ERROR':
        return SpectacularBarcodeErrorCode.noCamera;
      case 'SPECTACULAR_BARCODE_CAMERA_PERMISSION_DENIED':
        return SpectacularBarcodeErrorCode.permissionDenied;
      default:
        return SpectacularBarcodeErrorCode.genericError;
    }
  }

  @override
  Stream<BarcodeCapture?> get barcodesStream {
    return eventsStream
        .where((event) => event['name'] == 'barcode')
        .map(_parseBarcode);
  }

  @override
  Stream<TorchState> get torchStateStream {
    return eventsStream
        .where((event) => event['name'] == 'torchState')
        .map(
          (event) => TorchState.fromRawValue(
            (event['data'] as num?)?.toInt() ?? 0,
          ),
        );
  }

  @override
  Stream<double> get zoomScaleStateStream {
    return eventsStream
        .where((event) => event['name'] == 'zoomScaleState')
        .map((event) => (event['data'] as num?)?.toDouble() ?? 0.0);
  }

  @override
  Widget buildCameraView() {
    if (_textureId == null) {
      return const SizedBox.shrink();
    }

    final Widget texture = Texture(textureId: _textureId!);
    final delegate = _surfaceProducerDelegate;

    if (defaultTargetPlatform == TargetPlatform.android &&
        delegate != null &&
        !delegate.handlesCropAndRotation) {
      return RotatedPreview.fromCameraDirection(
        delegate.cameraFacingDirection,
        deviceOrientationStream: deviceOrientationChangedStream,
        initialDeviceOrientation: delegate.initialDeviceOrientation,
        sensorOrientationDegrees: delegate.sensorOrientationDegrees,
        child: texture,
      );
    }

    return texture;
  }

  @override
  Future<ViewAttributes> start(StartOptions startOptions) async {
    if (!_pausing && _textureId != null) {
      throw const SpectacularBarcodeException(
        errorCode: SpectacularBarcodeErrorCode.controllerAlreadyInitialized,
      );
    }

    await _requestCameraPermission();

    late final Map<Object?, Object?> startResult;
    try {
      final result = await methodChannel.invokeMapMethod<Object?, Object?>(
        'start',
        startOptions.toMap(),
      );
      if (result == null) {
        throw const SpectacularBarcodeException(
          errorCode: SpectacularBarcodeErrorCode.genericError,
          errorDetails: SpectacularBarcodeErrorDetails(
            message: 'The start method did not return a view configuration.',
          ),
        );
      }
      startResult = result;
    } on PlatformException catch (error) {
      throw SpectacularBarcodeException(
        errorCode: _mapPlatformError(error),
        errorDetails: SpectacularBarcodeErrorDetails(
          code: error.code,
          details: error.details,
          message: error.message,
        ),
      );
    }

    final textureId = startResult['textureId'] as int?;
    if (textureId == null) {
      throw const SpectacularBarcodeException(
        errorCode: SpectacularBarcodeErrorCode.genericError,
        errorDetails: SpectacularBarcodeErrorDetails(
          message: 'The start method did not return a texture id.',
        ),
      );
    }

    final cameraDirection = CameraFacing.fromRawValue(
      (startResult['cameraDirection'] as num?)?.toInt(),
    );

    _textureId = textureId;
    _pausing = false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      _surfaceProducerDelegate =
          AndroidSurfaceProducerDelegate.fromConfiguration(
        startResult,
        cameraDirection,
      );
    }

    final sizeMap = startResult['size'] as Map<Object?, Object?>?;
    final size = Size(
      (sizeMap?['width'] as num?)?.toDouble() ?? 0,
      (sizeMap?['height'] as num?)?.toDouble() ?? 0,
    );

    return ViewAttributes(
      cameraDirection: cameraDirection,
      currentTorchMode: TorchState.fromRawValue(
        (startResult['currentTorchState'] as num?)?.toInt() ?? -1,
      ),
      numberOfCameras: (startResult['numberOfCameras'] as num?)?.toInt(),
      size: size,
    );
  }

  @override
  Future<void> stop({bool force = false}) async {
    await methodChannel.invokeMethod<void>('stop', <String, Object?>{
      'force': force,
    });
    _textureId = null;
    _surfaceProducerDelegate = null;
    _pausing = false;
  }

  @override
  Future<void> pause({bool force = false}) async {
    await methodChannel.invokeMethod<void>('pause', <String, Object?>{
      'force': force,
    });
    _pausing = true;
  }

  @override
  Future<void> toggleTorch() async {
    await methodChannel.invokeMethod<void>('toggleTorch');
  }

  @override
  Future<void> setZoomScale(double zoomScale) async {
    await methodChannel.invokeMethod<void>('setScale', zoomScale);
  }

  @override
  Future<void> resetZoomScale() async {
    await methodChannel.invokeMethod<void>('resetScale');
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {
    await methodChannel.invokeMethod<void>('updateScanWindow', <String, Object?>{
      'rect': window == null
          ? null
          : <double>[window.left, window.top, window.right, window.bottom],
    });
  }

  @override
  Future<void> dispose() async {
    await stop(force: true);
  }
}
