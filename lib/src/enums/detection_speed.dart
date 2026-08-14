/// How often barcodes are reported.
enum DetectionSpeed {
  /// Ignore duplicate values until a different barcode is seen.
  noDuplicates(0),

  /// Apply a timeout between detections.
  normal(1),

  /// Report every detection with no throttling.
  unrestricted(2);

  const DetectionSpeed(this.rawValue);

  final int rawValue;
}
