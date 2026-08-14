/// Error codes for [SpectacularBarcodeException].
enum SpectacularBarcodeErrorCode {
  permissionDenied('Camera permission was denied.'),
  controllerAlreadyInitialized('The scanner was already started.'),
  controllerDisposed('The controller was disposed.'),
  controllerUninitialized('The controller is not initialized.'),
  controllerInitializing('The controller is already starting.'),
  noCamera('No cameras available.'),
  cameraError('An error occurred when opening the camera.'),
  genericError('An unknown error occurred.');

  const SpectacularBarcodeErrorCode(this.message);

  final String message;
}
