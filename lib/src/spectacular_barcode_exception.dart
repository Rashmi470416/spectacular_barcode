import 'package:spectacular_barcode/src/enums/error_code.dart';

/// Exception thrown by the SpectacularBarcode plugin.
class SpectacularBarcodeException implements Exception {
  const SpectacularBarcodeException({
    required this.errorCode,
    this.errorDetails,
  });

  final SpectacularBarcodeErrorCode errorCode;
  final SpectacularBarcodeErrorDetails? errorDetails;

  @override
  String toString() {
    final details = errorDetails?.message;
    if (details == null || details.isEmpty) {
      return 'SpectacularBarcodeException(${errorCode.name}): ${errorCode.message}';
    }
    return 'SpectacularBarcodeException(${errorCode.name}): $details';
  }
}

/// Optional platform error details.
class SpectacularBarcodeErrorDetails {
  const SpectacularBarcodeErrorDetails({
    this.code,
    this.details,
    this.message,
  });

  final String? code;
  final Object? details;
  final String? message;
}
