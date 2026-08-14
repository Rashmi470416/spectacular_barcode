import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:spectacular_barcode/src/enums/torch_state.dart';
import 'package:spectacular_barcode/src/method_channel/spectacular_barcode_method_channel.dart';
import 'package:spectacular_barcode/src/objects/barcode_capture.dart';
import 'package:spectacular_barcode/src/objects/start_options.dart';
import 'package:spectacular_barcode/src/objects/view_attributes.dart';

/// Platform interface for SpectacularBarcode.
abstract class SpectacularBarcodePlatform extends PlatformInterface {
  SpectacularBarcodePlatform() : super(token: _token);

  static final Object _token = Object();

  static SpectacularBarcodePlatform _instance =
      MethodChannelSpectacularBarcode();

  static SpectacularBarcodePlatform get instance => _instance;

  static set instance(SpectacularBarcodePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<BarcodeCapture?> get barcodesStream {
    throw UnimplementedError('barcodesStream has not been implemented.');
  }

  Stream<TorchState> get torchStateStream {
    throw UnimplementedError('torchStateStream has not been implemented.');
  }

  Stream<double> get zoomScaleStateStream {
    throw UnimplementedError('zoomScaleStateStream has not been implemented.');
  }

  Widget buildCameraView() {
    throw UnimplementedError('buildCameraView() has not been implemented.');
  }

  Future<ViewAttributes> start(StartOptions startOptions) {
    throw UnimplementedError('start() has not been implemented.');
  }

  Future<void> stop({bool force = false}) {
    throw UnimplementedError('stop() has not been implemented.');
  }

  Future<void> pause({bool force = false}) {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<void> toggleTorch() {
    throw UnimplementedError('toggleTorch() has not been implemented.');
  }

  Future<void> setZoomScale(double zoomScale) {
    throw UnimplementedError('setZoomScale() has not been implemented.');
  }

  Future<void> resetZoomScale() {
    throw UnimplementedError('resetZoomScale() has not been implemented.');
  }

  Future<void> updateScanWindow(Rect? window) {
    throw UnimplementedError('updateScanWindow() has not been implemented.');
  }

  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
