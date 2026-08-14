import 'package:flutter/material.dart';
import 'package:spectacular_barcode/src/overlay/scan_window_painter.dart';
import 'package:spectacular_barcode/src/spectacular_barcode_controller.dart';

/// Dimmed overlay with a visible scan-area cutout.
class ScanWindowOverlay extends StatelessWidget {
  const ScanWindowOverlay({
    required this.controller,
    required this.scanWindow,
    super.key,
    this.borderColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.borderWidth = 3,
    this.color = const Color(0x99000000),
    this.cornerLength = 28,
  });

  final Color borderColor;
  final BorderRadius borderRadius;
  final double borderWidth;
  final Color color;
  final SpectacularBarcodeController controller;
  final double cornerLength;
  final Rect scanWindow;

  @override
  Widget build(BuildContext context) {
    if (scanWindow.isEmpty || scanWindow.isInfinite) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized ||
            !value.isRunning ||
            value.error != null ||
            value.size.isEmpty) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          size: Size.infinite,
          painter: ScanWindowPainter(
            scanWindow: scanWindow,
            borderColor: borderColor,
            borderRadius: borderRadius,
            borderWidth: borderWidth,
            color: color,
            cornerLength: cornerLength,
          ),
        );
      },
    );
  }
}
