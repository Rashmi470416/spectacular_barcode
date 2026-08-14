import 'package:flutter/material.dart';

/// Paints a dimmed overlay with a clear [scanWindow] cutout and border.
class ScanWindowPainter extends CustomPainter {
  const ScanWindowPainter({
    required this.scanWindow,
    this.borderColor = Colors.white,
    this.borderRadius = BorderRadius.zero,
    this.borderWidth = 3,
    this.color = const Color(0x99000000),
    this.cornerLength = 28,
  });

  final Color borderColor;
  final BorderRadius borderRadius;
  final double borderWidth;
  final Color color;
  final double cornerLength;
  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    if (scanWindow.isEmpty || scanWindow.isInfinite) {
      return;
    }

    final backgroundPath = Path()..addRect(Offset.zero & size);
    final cutoutRect = borderRadius == BorderRadius.zero
        ? RRect.fromRectAndCorners(scanWindow)
        : RRect.fromRectAndCorners(
            scanWindow,
            topLeft: borderRadius.topLeft,
            topRight: borderRadius.topRight,
            bottomLeft: borderRadius.bottomLeft,
            bottomRight: borderRadius.bottomRight,
          );
    final cutoutPath = Path()..addRRect(cutoutRect);

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = scanWindow.left;
    final top = scanWindow.top;
    final right = scanWindow.right;
    final bottom = scanWindow.bottom;
    final len = cornerLength;

    // Top-left
    canvas
      ..drawLine(Offset(left, top), Offset(left + len, top), cornerPaint)
      ..drawLine(Offset(left, top), Offset(left, top + len), cornerPaint)
      // Top-right
      ..drawLine(Offset(right, top), Offset(right - len, top), cornerPaint)
      ..drawLine(Offset(right, top), Offset(right, top + len), cornerPaint)
      // Bottom-left
      ..drawLine(Offset(left, bottom), Offset(left + len, bottom), cornerPaint)
      ..drawLine(Offset(left, bottom), Offset(left, bottom - len), cornerPaint)
      // Bottom-right
      ..drawLine(Offset(right, bottom), Offset(right - len, bottom), cornerPaint)
      ..drawLine(Offset(right, bottom), Offset(right, bottom - len), cornerPaint);
  }

  @override
  bool shouldRepaint(ScanWindowPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
