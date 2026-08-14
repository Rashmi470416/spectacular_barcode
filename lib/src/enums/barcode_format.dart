/// Supported barcode formats.
enum BarcodeFormat {
  unknown(-1),
  all(0),
  code128(1),
  code39(2),
  code93(4),
  codabar(8),
  dataMatrix(16),
  ean13(32),
  ean8(64),
  itf(128),
  qrCode(256),
  upcA(512),
  upcE(1024),
  pdf417(2048),
  aztec(4096);

  const BarcodeFormat(this.rawValue);

  factory BarcodeFormat.fromRawValue(int value) {
    return BarcodeFormat.values.firstWhere(
      (format) => format.rawValue == value,
      orElse: () => BarcodeFormat.unknown,
    );
  }

  /// Raw value exchanged with the native platform.
  final int rawValue;
}
