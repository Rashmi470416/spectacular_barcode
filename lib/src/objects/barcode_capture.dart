import 'dart:typed_data';
import 'dart:ui';

import 'package:spectacular_barcode/src/objects/barcode.dart';

/// A set of barcodes detected in a single camera frame or image.
class BarcodeCapture {
  const BarcodeCapture({
    this.barcodes = const <Barcode>[],
    this.image,
    this.raw,
    this.size = Size.zero,
  });

  final List<Barcode> barcodes;
  final Uint8List? image;
  final Object? raw;
  final Size size;
}
