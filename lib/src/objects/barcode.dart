import 'dart:typed_data';
import 'dart:ui';

import 'package:spectacular_barcode/src/enums/barcode_format.dart';

/// A single recognized barcode.
class Barcode {
  const Barcode({
    this.corners = const <Offset>[],
    this.displayValue,
    this.format = BarcodeFormat.unknown,
    this.rawBytes,
    this.rawValue,
    this.size = Size.zero,
    this.type = 0,
  });

  factory Barcode.fromNative(Map<Object?, Object?> data) {
    final corners = data['corners'] as List<Object?>?;
    final size = data['size'] as Map<Object?, Object?>?;

    return Barcode(
      corners: corners == null
          ? const <Offset>[]
          : List.unmodifiable(
              corners.cast<Map<Object?, Object?>>().map((corner) {
                return Offset(
                  (corner['x'] as num?)?.toDouble() ?? 0,
                  (corner['y'] as num?)?.toDouble() ?? 0,
                );
              }),
            ),
      displayValue: data['displayValue'] as String?,
      format: BarcodeFormat.fromRawValue(
        (data['format'] as num?)?.toInt() ?? -1,
      ),
      rawBytes: data['rawBytes'] as Uint8List?,
      rawValue: data['rawValue'] as String?,
      size: Size(
        (size?['width'] as num?)?.toDouble() ?? 0,
        (size?['height'] as num?)?.toDouble() ?? 0,
      ),
      type: (data['type'] as num?)?.toInt() ?? 0,
    );
  }

  final List<Offset> corners;
  final String? displayValue;
  final BarcodeFormat format;
  final Uint8List? rawBytes;
  final String? rawValue;
  final Size size;
  final int type;
}
