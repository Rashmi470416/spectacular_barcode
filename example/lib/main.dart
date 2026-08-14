import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spectacular_barcode/barcode.dart';
import 'package:spectacular_barcode/barcode_capture.dart';
import 'package:spectacular_barcode/scan_window_overlay.dart';
import 'package:spectacular_barcode/spectacular_barcode_controller.dart';
import 'package:spectacular_barcode/spectacular_barcode_exception.dart';
import 'package:spectacular_barcode/spectacular_barcode_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      title: 'Spectacular Barcode Example',
      home: _ExampleHome(),
    ),
  );
}

class _ExampleHome extends StatelessWidget {
  const _ExampleHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spectacular Barcode')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SimpleScannerPage(),
              ),
            );
          },
          child: const Text('Open scanner'),
        ),
      ),
    );
  }
}

class SimpleScannerPage extends StatefulWidget {
  const SimpleScannerPage({super.key});

  @override
  State<SimpleScannerPage> createState() => _SimpleScannerPageState();
}

class _SimpleScannerPageState extends State<SimpleScannerPage> {
  Barcode? _barcode;
  late SpectacularBarcodeController _controller;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _controller = SpectacularBarcodeController();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (!_isScanning || !mounted || capture.barcodes.isEmpty) {
      return;
    }

    final barcode = capture.barcodes.first;
    setState(() {
      _isScanning = false;
      _barcode = barcode;
    });

    try {
      await _controller.stop();
    } on SpectacularBarcodeException {
      // Ignore stop errors after a successful capture.
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _barcode = null;
      _isScanning = true;
    });

    // Recreate controller so the camera/texture starts cleanly.
    await _controller.dispose();
    _controller = SpectacularBarcodeController();
    setState(() {});
  }

  Future<void> _safeToggleTorch() async {
    if (!_isScanning) {
      return;
    }
    try {
      await _controller.toggleTorch();
    } on SpectacularBarcodeException catch (error) {
      _showMessage(error.errorCode.message);
    }
  }

  Future<void> _safeSwitchCamera() async {
    if (!_isScanning) {
      return;
    }
    try {
      await _controller.switchCamera();
    } on SpectacularBarcodeException catch (error) {
      _showMessage(error.errorCode.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copyResult() async {
    final text = _barcode?.displayValue ?? _barcode?.rawValue;
    if (text == null || text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('Copied to clipboard');
  }

  Rect _scanWindowFor(Size size) {
    final side = size.width * 0.72;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 24),
      width: side,
      height: side,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultText = _barcode?.displayValue ?? _barcode?.rawValue;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isScanning ? 'Simple scanner' : 'Scan result'),
        actions: [
          if (_isScanning) ...[
            IconButton(
              tooltip: 'Toggle torch',
              onPressed: _safeToggleTorch,
              icon: const Icon(Icons.flash_on),
            ),
            IconButton(
              tooltip: 'Switch camera',
              onPressed: _safeSwitchCamera,
              icon: const Icon(Icons.cameraswitch),
            ),
          ],
        ],
      ),
      backgroundColor: Colors.black,
      body: _isScanning
          ? LayoutBuilder(
              builder: (context, constraints) {
                final scanWindow = _scanWindowFor(constraints.biggest);

                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    SpectacularBarcodeView(
                      controller: _controller,
                      scanWindow: scanWindow,
                      onDetect: _handleBarcode,
                      overlayBuilder: (context, constraints) {
                        return ScanWindowOverlay(
                          controller: _controller,
                          scanWindow: scanWindow,
                        );
                      },
                      errorBuilder: (context, error) {
                        return ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                error.errorDetails?.message ??
                                    error.errorCode.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                        child: Text(
                          'Align barcode inside the scan area',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const Icon(
                      Icons.qr_code_2,
                      color: Colors.white,
                      size: 72,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Scanned value',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      resultText ?? 'No value',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _copyResult,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _scanAgain,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan again'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
