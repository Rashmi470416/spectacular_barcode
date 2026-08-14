import AVFoundation
import Flutter
import UIKit
import Vision
import VideoToolbox

/// iOS implementation of SpectacularBarcode using the same MethodChannel API as Android.
public class SpectacularBarcodePlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
  FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate
{
  private let registry: FlutterTextureRegistry
  private var eventSink: FlutterEventSink?
  private var textureId: Int64?
  private var captureSession: AVCaptureSession?
  private weak var device: AVCaptureDevice?
  private var latestBuffer: CVImageBuffer?
  private var scanWindow: CGRect?
  private var detectionSpeed: Int = 1
  private var timeoutSeconds: Double = 0.25
  private var nextScanTime: TimeInterval = 0
  private var imagesCurrentlyBeingProcessed = false
  private var lastScannedValues: [String] = []
  private var symbologies: [VNBarcodeSymbology] = []
  private var position: AVCaptureDevice.Position = .back
  private var isPaused = false

  private var stopped: Bool {
    device == nil || captureSession == nil
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SpectacularBarcodePlugin(registry: registrar.textures())
    let method = FlutterMethodChannel(
      name: "com.zequetech.spectacular_barcode/scanner/method",
      binaryMessenger: registrar.messenger()
    )
    let event = FlutterEventChannel(
      name: "com.zequetech.spectacular_barcode/scanner/event",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: method)
    event.setStreamHandler(instance)
  }

  init(registry: FlutterTextureRegistry) {
    self.registry = registry
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "state":
      checkPermission(result)
    case "request":
      requestPermission(result)
    case "start":
      start(call, result)
    case "stop":
      stop(call, result)
    case "pause":
      pause(call, result)
    case "toggleTorch":
      toggleTorch(result)
    case "setScale":
      setScale(call, result)
    case "resetScale":
      resetScale(result)
    case "updateScanWindow":
      updateScanWindow(call, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - FlutterTexture

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let buffer = latestBuffer else {
      return nil
    }
    return Unmanaged.passRetained(buffer)
  }

  // MARK: - Permissions

  private func checkPermission(_ result: @escaping FlutterResult) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .notDetermined:
      result(0)
    case .authorized:
      result(1)
    default:
      result(2)
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    AVCaptureDevice.requestAccess(for: .video) { granted in
      DispatchQueue.main.async {
        result(granted)
      }
    }
  }

  // MARK: - Camera control

  private func start(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if device != nil || captureSession != nil {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_ALREADY_STARTED_ERROR",
          message: "The scanner was already started.",
          details: nil
        )
      )
      return
    }

    let args = call.arguments as? [String: Any] ?? [:]
    let torch = args["torch"] as? Bool ?? false
    let facing = args["facing"] as? Int ?? 1
    let speed = args["speed"] as? Int ?? 1
    let timeoutMs = args["timeout"] as? Int ?? 250
    let formats = args["formats"] as? [Int]
    let initialZoom = args["initialZoom"] as? Double

    detectionSpeed = speed
    timeoutSeconds = Double(timeoutMs) / 1000.0
    symbologies = Self.mapFormats(formats)
    position = facing == 0 ? .front : .back
    isPaused = false

    textureId = textureId ?? registry.register(self)
    captureSession = AVCaptureSession()

    guard
      let camera = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: position
      )
    else {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_NO_CAMERA_ERROR",
          message: "No cameras available.",
          details: nil
        )
      )
      return
    }

    device = camera
    captureSession?.beginConfiguration()
    captureSession?.sessionPreset = .high

    do {
      let input = try AVCaptureDeviceInput(device: camera)
      guard let session = captureSession, session.canAddInput(input) else {
        result(
          FlutterError(
            code: "SPECTACULAR_BARCODE_CAMERA_ERROR",
            message: "An error occurred when opening the camera.",
            details: nil
          )
        )
        return
      }
      session.addInput(input)
    } catch {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_CAMERA_ERROR",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }

    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)

    guard let session = captureSession, session.canAddOutput(videoOutput) else {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_CAMERA_ERROR",
          message: "An error occurred when opening the camera.",
          details: nil
        )
      )
      return
    }
    session.addOutput(videoOutput)

    if let connection = videoOutput.connections.first {
      if connection.isVideoOrientationSupported {
        connection.videoOrientation = .portrait
      }
      if position == .front && connection.isVideoMirroringSupported {
        connection.isVideoMirrored = true
      }
    }

    captureSession?.commitConfiguration()

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      self.captureSession?.startRunning()

      DispatchQueue.main.async {
        if torch {
          self.setTorch(enabled: true)
        }
        if let initialZoom {
          try? self.applyZoom(initialZoom)
        }

        let dimensions = CMVideoFormatDescriptionGetDimensions(
          camera.activeFormat.formatDescription
        )
        // Swap width/height for portrait default orientation (same as mobile_scanner).
        let size: [String: Double] = [
          "width": Double(dimensions.height),
          "height": Double(dimensions.width),
        ]

        let cameraDirection: Int? = {
          switch camera.position {
          case .front: return 0
          case .back: return 1
          default: return nil
          }
        }()

        let torchState: Int
        if camera.hasTorch {
          torchState = camera.torchMode == .on ? 1 : 0
        } else {
          torchState = -1
        }

        result([
          "textureId": self.textureId as Any,
          "size": size,
          "currentTorchState": torchState,
          "numberOfCameras": AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
          ).devices.count,
          "cameraDirection": cameraDirection as Any,
          "sensorOrientation": 90,
          "handlesCropAndRotation": true,
          "naturalDeviceOrientation": "PORTRAIT_UP",
        ])
      }
    }
  }

  private func stop(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let force = args?["force"] as? Bool ?? false
    if !force && stopped && !isPaused {
      result(nil)
      return
    }
    releaseCamera(keepTexture: false)
    result(nil)
  }

  private func pause(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let force = args?["force"] as? Bool ?? false
    if !force && (isPaused || stopped) {
      result(nil)
      return
    }
    releaseCamera(keepTexture: true)
    isPaused = true
    result(nil)
  }

  private func releaseCamera(keepTexture: Bool) {
    captureSession?.stopRunning()
    captureSession = nil
    device = nil
    latestBuffer = nil
    lastScannedValues = []
    imagesCurrentlyBeingProcessed = false

    if !keepTexture, let textureId {
      registry.unregisterTexture(textureId)
      self.textureId = nil
    }
  }

  private func toggleTorch(_ result: @escaping FlutterResult) {
    guard let device, device.hasTorch else {
      result(nil)
      return
    }
    let enable = device.torchMode != .on
    setTorch(enabled: enable)
    result(nil)
  }

  private func setTorch(enabled: Bool) {
    guard let device, device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      if enabled && device.isTorchModeSupported(.on) {
        device.torchMode = .on
      } else if device.isTorchModeSupported(.off) {
        device.torchMode = .off
      }
      device.unlockForConfiguration()
      publishEvent(["name": "torchState", "data": enabled ? 1 : 0])
    } catch {
      // Ignore torch failures.
    }
  }

  private func setScale(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let scale = call.arguments as? Double else {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_GENERIC_ERROR",
          message: "The zoom scale should be between 0 and 1 (both inclusive)",
          details: nil
        )
      )
      return
    }
    guard device != nil else {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_SET_SCALE_WHEN_STOPPED_ERROR",
          message: "The zoom scale cannot be changed when the camera is stopped.",
          details: nil
        )
      )
      return
    }
    do {
      try applyZoom(scale)
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_GENERIC_ERROR",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func resetScale(_ result: @escaping FlutterResult) {
    guard device != nil else {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_SET_SCALE_WHEN_STOPPED_ERROR",
          message: "The zoom scale cannot be changed when the camera is stopped.",
          details: nil
        )
      )
      return
    }
    do {
      try applyZoom(0)
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "SPECTACULAR_BARCODE_GENERIC_ERROR",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func applyZoom(_ linearZoom: Double) throws {
    guard let device else { return }
    let clamped = max(0.0, min(1.0, linearZoom))
    let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
    let factor = 1.0 + (maxZoom - 1.0) * CGFloat(clamped)
    try device.lockForConfiguration()
    device.videoZoomFactor = factor
    device.unlockForConfiguration()
    publishEvent(["name": "zoomScaleState", "data": clamped])
  }

  private func updateScanWindow(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let rect = args?["rect"] as? [Double], rect.count >= 4 else {
      scanWindow = nil
      result(nil)
      return
    }
    let left = CGFloat(rect[0])
    let top = CGFloat(rect[1])
    let right = CGFloat(rect[2])
    let bottom = CGFloat(rect[3])
    // Vision uses bottom-left origin; flip Y like mobile_scanner.
    scanWindow = CGRect(
      x: left,
      y: 1.0 - bottom,
      width: right - left,
      height: bottom - top
    )
    result(nil)
  }

  // MARK: - Frame processing

  public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard textureId != nil else { return }
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    latestBuffer = imageBuffer
    registry.textureFrameAvailable(textureId!)

    let now = Date().timeIntervalSince1970
    let eligible =
      (detectionSpeed == 2)
      || (now > nextScanTime && !imagesCurrentlyBeingProcessed)

    guard eligible else { return }

    nextScanTime = now + timeoutSeconds
    imagesCurrentlyBeingProcessed = true

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      defer { self.imagesCurrentlyBeingProcessed = false }

      guard let buffer = self.latestBuffer else { return }

      var cgImage: CGImage?
      let status = VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)
      guard status == kCVReturnSuccess, let image = cgImage else { return }

      let request = VNDetectBarcodesRequest { [weak self] request, error in
        guard let self else { return }
        if let error {
          DispatchQueue.main.async {
            self.eventSink?(
              FlutterError(
                code: "SPECTACULAR_BARCODE_BARCODE_ERROR",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
          return
        }

        guard let observations = request.results as? [VNBarcodeObservation], !observations.isEmpty
        else {
          return
        }

        let barcodes = observations.map { $0.toSpectacularMap(imageWidth: image.width, imageHeight: image.height) }
        let values = barcodes.compactMap { $0["rawValue"] as? String }.sorted()

        if self.detectionSpeed == 0, values == self.lastScannedValues {
          return
        }
        if !values.isEmpty {
          self.lastScannedValues = values
        }

        let imageData: [String: Any?] = [
          "bytes": nil,
          "width": Double(min(image.width, image.height)),
          "height": Double(max(image.width, image.height)),
        ]

        DispatchQueue.main.async {
          self.publishEvent([
            "name": "barcode",
            "data": barcodes,
            "image": imageData,
          ])
        }
      }

      if !self.symbologies.isEmpty {
        request.symbologies = self.symbologies
      }
      if let scanWindow = self.scanWindow {
        request.regionOfInterest = scanWindow
      }

      let handler = VNImageRequestHandler(cgImage: image, options: [:])
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          self.eventSink?(
            FlutterError(
              code: "SPECTACULAR_BARCODE_BARCODE_ERROR",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func publishEvent(_ event: [String: Any?]) {
    eventSink?(event)
  }

  // MARK: - Format mapping

  private static func mapFormats(_ formats: [Int]?) -> [VNBarcodeSymbology] {
    guard let formats, !formats.isEmpty else { return [] }
    var result: [VNBarcodeSymbology] = []
    for format in formats {
      switch format {
      case 1: result.append(.code128)
      case 2: result.append(.code39)
      case 4: result.append(.code93)
      case 8:
        if #available(iOS 15.0, *) {
          result.append(.codabar)
        }
      case 16: result.append(.dataMatrix)
      case 32: result.append(.ean13)
      case 64: result.append(.ean8)
      case 126, 127, 128: result.append(.itf14)
      case 256: result.append(.qr)
      case 512, 1024: result.append(.upce)
      case 2048: result.append(.pdf417)
      case 4096: result.append(.aztec)
      default: break
      }
    }
    return result
  }
}

// MARK: - Barcode mapping

extension VNBarcodeObservation {
  fileprivate func toSpectacularMap(imageWidth: Int, imageHeight: Int) -> [String: Any?] {
    let w = CGFloat(imageWidth)
    let h = CGFloat(imageHeight)

    let corners: [[String: Double]] = [
      ["x": Double(topLeft.x * w), "y": Double((1 - topLeft.y) * h)],
      ["x": Double(topRight.x * w), "y": Double((1 - topRight.y) * h)],
      ["x": Double(bottomRight.x * w), "y": Double((1 - bottomRight.y) * h)],
      ["x": Double(bottomLeft.x * w), "y": Double((1 - bottomLeft.y) * h)],
    ]

    let boxWidth = hypot(topLeft.x - topRight.x, topLeft.y - topRight.y) * w
    let boxHeight = hypot(topLeft.x - bottomLeft.x, topLeft.y - bottomLeft.y) * h

    return [
      "corners": corners,
      "displayValue": payloadStringValue,
      "format": symbology.toDartFormat(),
      "rawBytes": payloadStringValue?.data(using: .utf8).map { FlutterStandardTypedData(bytes: $0) },
      "rawValue": payloadStringValue,
      "size": [
        "width": Double(boxWidth),
        "height": Double(boxHeight),
      ],
      "type": 0,
    ]
  }
}

extension VNBarcodeSymbology {
  fileprivate func toDartFormat() -> Int {
    if #available(iOS 15.0, *), self == .codabar {
      return 8
    }
    switch self {
    case .code128: return 1
    case .code39: return 2
    case .code93: return 4
    case .dataMatrix: return 16
    case .ean13: return 32
    case .ean8: return 64
    case .itf14: return 128
    case .qr: return 256
    case .upce: return 1024
    case .pdf417: return 2048
    case .aztec: return 4096
    default: return -1
    }
  }
}
