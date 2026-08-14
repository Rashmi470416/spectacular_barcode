import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spectacular_barcode/src/method_channel/spectacular_barcode_method_channel.dart';
import 'package:spectacular_barcode/src/objects/barcode_capture.dart';
import 'package:spectacular_barcode/src/objects/scanner_state.dart';
import 'package:spectacular_barcode/src/overlay/scan_window_overlay.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_controller.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_exception.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_platform_interface.dart';

/// Live camera preview widget for barcode scanning.
class SpectacularBarcodeView extends StatefulWidget {
  const SpectacularBarcodeView({
    super.key,
    this.controller,
    this.onDetect,
    this.onDetectError = _onDetectErrorHandler,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.overlayBuilder,
    this.placeholderBuilder,
    this.scanWindow,
    this.showScanWindowOverlay = true,
    this.useAppLifecycleState = true,
  });

  final SpectacularBarcodeController? controller;
  final void Function(BarcodeCapture barcodes)? onDetect;
  final void Function(Object error, StackTrace stackTrace) onDetectError;
  final Widget Function(BuildContext, SpectacularBarcodeException)?
      errorBuilder;
  final BoxFit fit;
  final LayoutWidgetBuilder? overlayBuilder;
  final WidgetBuilder? placeholderBuilder;
  final Rect? scanWindow;

  /// When true and [scanWindow] is set, draws a dimmed cutout overlay.
  final bool showScanWindowOverlay;
  final bool useAppLifecycleState;

  static void _onDetectErrorHandler(Object error, StackTrace stackTrace) {}

  @override
  State<SpectacularBarcodeView> createState() => _SpectacularBarcodeViewState();
}

class _SpectacularBarcodeViewState extends State<SpectacularBarcodeView>
    with WidgetsBindingObserver {
  late final SpectacularBarcodeController controller;
  StreamSubscription<BarcodeCapture>? _subscription;
  Rect? _scanWindow;

  Future<void> _initializeController() async {
    controller = widget.controller ?? SpectacularBarcodeController();
    controller.attach();

    if (kDebugMode) {
      final platform = SpectacularBarcodePlatform.instance;
      if (platform is MethodChannelSpectacularBarcode) {
        try {
          await platform.stop(force: true);
        } on Exception catch (error) {
          debugPrint('$error');
        }
      }
    }

    if (widget.controller == null) {
      WidgetsBinding.instance.addObserver(this);
    }

    if (widget.onDetect != null) {
      _subscription = controller.barcodes.listen(
        widget.onDetect,
        onError: widget.onDetectError,
        cancelOnError: false,
      );
    }

    if (controller.autoStart) {
      await controller.start();
    }
  }

  Future<void> _disposeController() async {
    if (widget.controller == null) {
      WidgetsBinding.instance.removeObserver(this);
    }

    await _subscription?.cancel();
    _subscription = null;

    if (controller.autoStart) {
      await controller.stop();
    }

    if (widget.controller == null) {
      await controller.dispose();
    }
  }

  void _maybeUpdateScanWindow(
    ScannerState scannerState,
    BoxConstraints constraints,
  ) {
    if (widget.scanWindow == null && _scanWindow == null) {
      return;
    }

    if (widget.scanWindow == null) {
      _scanWindow = null;
      unawaited(controller.updateScanWindow(null));
      return;
    }

    if (!scannerState.isInitialized || scannerState.size == Size.zero) {
      return;
    }

    final widgetSize = constraints.biggest;
    final textureSize = scannerState.size;
    final fitted = applyBoxFit(widget.fit, textureSize, widgetSize);
    final output = fitted.destination;
    final offset = Offset(
      (widgetSize.width - output.width) / 2,
      (widgetSize.height - output.height) / 2,
    );

    final local = widget.scanWindow!;
    final left = ((local.left - offset.dx) / output.width).clamp(0.0, 1.0);
    final top = ((local.top - offset.dy) / output.height).clamp(0.0, 1.0);
    final right = ((local.right - offset.dx) / output.width).clamp(0.0, 1.0);
    final bottom = ((local.bottom - offset.dy) / output.height).clamp(0.0, 1.0);

    final relative = Rect.fromLTRB(left, top, right, bottom);
    if (_scanWindow == relative) {
      return;
    }

    _scanWindow = relative;
    unawaited(controller.updateScanWindow(relative));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initializeController());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScannerState>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized || value.isStarting) {
          return widget.placeholderBuilder?.call(context) ??
              const ColoredBox(color: Colors.black);
        }

        final error = value.error;
        if (error != null) {
          final defaultError = ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Icon(Icons.error, color: Colors.white),
                  ),
                  Text(
                    error.errorCode.message,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
          return widget.errorBuilder?.call(context, error) ?? defaultError;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            _maybeUpdateScanWindow(value, constraints);

            final scannerWidget = ClipRect(
              child: SizedBox.fromSize(
                size: constraints.biggest,
                child: FittedBox(
                  fit: widget.fit,
                  child: SizedBox(
                    width: value.size.width,
                    height: value.size.height,
                    child: controller.buildCameraView(),
                  ),
                ),
              ),
            );

            final customOverlay =
                widget.overlayBuilder?.call(context, constraints);
            final scanWindow = widget.scanWindow;
            final scanOverlay =
                widget.showScanWindowOverlay && scanWindow != null
                    ? ScanWindowOverlay(
                        controller: controller,
                        scanWindow: scanWindow,
                      )
                    : null;

            if (customOverlay == null && scanOverlay == null) {
              return scannerWidget;
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                scannerWidget,
                ?scanOverlay,
                ?customOverlay,
              ],
            );
          },
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.useAppLifecycleState || !controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(controller.start());
      case AppLifecycleState.inactive:
        unawaited(controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }
}
