# spectacular_barcode

A Flutter barcode and QR code scanner built with **MethodChannel** and native code:

- **Android** — CameraX + ML Kit (Kotlin)
- **iOS** — AVFoundation + Vision (Swift)

Includes a live camera preview, scan-window overlay, torch, zoom, and camera switching.

## Features

- Live camera preview via Flutter texture
- Barcode / QR detection on device
- Visible scan area (cutout overlay)
- Torch toggle and zoom
- Front / back camera switch
- Same Dart API on Android and iOS

## Supported platforms

| Platform | Status |
|----------|--------|
| Android  | Supported (minSdk 24) |
| iOS      | Supported (iOS 13+) |

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  spectacular_barcode:
    path: ../spectacular_barcode   # or git / pub.dev when published
```

Then run:

```bash
flutter pub get
```

## Permissions

### Android

The plugin declares the camera permission. Ensure your app merges it (already included by the plugin):

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Runtime permission is requested when the scanner starts.

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan barcodes and QR codes.</string>
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:spectacular_barcode/spectacular_barcode.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _controller = SpectacularBarcodeController();
  String? _value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpectacularBarcodeView(
        controller: _controller,
        onDetect: (capture) {
          if (capture.barcodes.isEmpty) return;
          setState(() {
            _value = capture.barcodes.first.rawValue;
          });
          _controller.stop();
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_value ?? 'Scan a barcode'),
        ),
      ),
    );
  }
}
```

## Scan window overlay

Pass a `scanWindow` to limit detection and show a framed cutout:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final size = constraints.biggest;
    final side = size.width * 0.72;
    final scanWindow = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );

    return SpectacularBarcodeView(
      controller: controller,
      scanWindow: scanWindow,
      overlayBuilder: (context, constraints) {
        return ScanWindowOverlay(
          controller: controller,
          scanWindow: scanWindow,
        );
      },
      onDetect: (capture) {
        // handle result
      },
    );
  },
);
```

## Controller API

| Method | Description |
|--------|-------------|
| `start()` | Request permission and start the camera |
| `stop()` | Stop the camera |
| `pause()` | Pause the camera |
| `toggleTorch()` | Toggle flashlight |
| `setZoomScale(double)` | Zoom between `0.0` and `1.0` |
| `resetZoomScale()` | Reset zoom |
| `switchCamera()` | Switch front / back |
| `barcodes` | Stream of `BarcodeCapture` events |

## Example app

```bash
cd example
flutter pub get
flutter run
```

The example shows a full-screen scanner with a scan area, then displays the scanned value with **Copy** and **Scan again**.

## Architecture

Flutter talks to native code over MethodChannel / EventChannel:

- Method: `com.zequetech.spectacular_barcode/scanner/method`
- Event: `com.zequetech.spectacular_barcode/scanner/event`

Methods: `state`, `request`, `start`, `stop`, `pause`, `toggleTorch`, `setScale`, `resetScale`, `updateScanWindow`

## License

MIT License. See [LICENSE](LICENSE).
