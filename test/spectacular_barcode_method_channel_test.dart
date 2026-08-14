import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectacular_barcode/src/enums/camera_facing.dart';
import 'package:spectacular_barcode/src/enums/detection_speed.dart';
import 'package:spectacular_barcode/src/method_channel/spectacular_barcode_method_channel.dart';
import 'package:spectacular_barcode/src/objects/start_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'com.zequetech.spectacular_barcode/scanner/method',
  );

  final calls = <MethodCall>[];
  late MethodChannelSpectacularBarcode platform;

  setUp(() {
    platform = MethodChannelSpectacularBarcode();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      switch (methodCall.method) {
        case 'state':
          return 1;
        case 'start':
          return <String, Object?>{
            'textureId': 7,
            'size': <String, Object?>{'width': 1080.0, 'height': 1920.0},
            'currentTorchState': 0,
            'numberOfCameras': 2,
            'cameraDirection': 1,
          };
        case 'stop':
        case 'pause':
        case 'toggleTorch':
        case 'resetScale':
        case 'updateScanWindow':
        case 'setScale':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start requests permission state and returns view attributes', () async {
    final attributes = await platform.start(
      const StartOptions(
        cameraDirection: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 250,
        formats: [],
        returnImage: false,
        torchEnabled: false,
      ),
    );

    expect(
      calls.map((call) => call.method),
      containsAll(<String>['state', 'start']),
    );
    expect(attributes.size.width, 1080);
    expect(attributes.size.height, 1920);
    expect(attributes.cameraDirection, CameraFacing.back);
  });

  test('stop clears texture', () async {
    await platform.start(
      const StartOptions(
        cameraDirection: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 250,
        formats: [],
        returnImage: false,
        torchEnabled: false,
      ),
    );
    await platform.stop();
    expect(calls.last.method, 'stop');
  });
}
