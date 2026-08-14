import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:spectacular_barcode/spectacular_barcode.dart';
import 'package:spectacular_barcode/src/method_channel/spectacular_barcode_method_channel.dart';

class MockSpectacularBarcodePlatform
    with MockPlatformInterfaceMixin
    implements SpectacularBarcodePlatform {
  bool started = false;
  bool stopped = false;
  bool torchToggled = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const SizedBox.shrink();

  @override
  Future<ViewAttributes> start(StartOptions startOptions) async {
    started = true;
    return const ViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      numberOfCameras: 2,
      size: Size(1080, 1920),
    );
  }

  @override
  Future<void> stop({bool force = false}) async {
    stopped = true;
  }

  @override
  Future<void> pause({bool force = false}) async {}

  @override
  Future<void> toggleTorch() async {
    torchToggled = true;
  }

  @override
  Future<void> setZoomScale(double zoomScale) async {}

  @override
  Future<void> resetZoomScale() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MethodChannelSpectacularBarcode is the default instance', () {
    expect(
      SpectacularBarcodePlatform.instance,
      isA<MethodChannelSpectacularBarcode>(),
    );
  });

  test('controller start uses platform interface', () async {
    final fakePlatform = MockSpectacularBarcodePlatform();
    SpectacularBarcodePlatform.instance = fakePlatform;

    final controller = SpectacularBarcodeController(autoStart: false);
    controller.attach();
    await controller.start();

    expect(fakePlatform.started, isTrue);
    expect(controller.value.isRunning, isTrue);
    expect(controller.value.size, const Size(1080, 1920));

    await controller.toggleTorch();
    expect(fakePlatform.torchToggled, isTrue);

    await controller.stop();
    expect(fakePlatform.stopped, isTrue);

    await controller.dispose();
  });
}
