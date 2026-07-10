// DataMatrixScannerView.swift
// react-native-datamatrix-scanner
//
// Vision-based view that decodes DataMatrix codes from the device rear camera
// using AVCaptureVideoDataOutput and Apple's Vision framework. Supports color inversion.

import AVFoundation
import CoreImage
import ExpoModulesCore
import UIKit
import Vision

// ---------------------------------------------------------------------------
// MARK: – View
// ---------------------------------------------------------------------------

/// Native UIView that embeds an AVCaptureSession configured to detect
/// **DataMatrix** codes only. Supports standard and inverted codes.
class DataMatrixScannerView: ExpoView, AVCaptureVideoDataOutputSampleBufferDelegate {

  // -----------------------------------------------------------------------
  // MARK: Events
  // -----------------------------------------------------------------------

  let onScanned     = EventDispatcher()
  let onCameraReady = EventDispatcher()
  let onMountError  = EventDispatcher()

  // -----------------------------------------------------------------------
  // MARK: Session infrastructure
  // -----------------------------------------------------------------------

  private let session         = AVCaptureSession()
  private let sessionQueue    = DispatchQueue(label: "expo.datamatrixscanner.session")
  private var previewLayer    : AVCaptureVideoPreviewLayer?
  private let videoDataOutput = AVCaptureVideoDataOutput()
  private var captureDevice   : AVCaptureDevice?
  private var sessionStarted  = false
  private var isProcessingFrame = false

  // -----------------------------------------------------------------------
  // MARK: Props
  // -----------------------------------------------------------------------

  /// Turns the device torch on or off.
  var enableTorch: Bool = false {
    didSet {
      sessionQueue.async { [weak self] in
        self?.applyTorch()
      }
    }
  }

  /// Turns inverse scanning mode on or off.
  var enableInverse: Bool = false

  // -----------------------------------------------------------------------
  // MARK: ExpoView lifecycle
  // -----------------------------------------------------------------------

  required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    backgroundColor = .black
    setupPreviewLayer()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer?.frame = bounds

    let orientation = currentVideoOrientation()
    // Keep preview layer video orientation in sync with device orientation.
    if let connection = previewLayer?.connection, connection.isVideoOrientationSupported {
      connection.videoOrientation = orientation
    }
    // Keep video data output connection orientation in sync.
    if let connection = videoDataOutput.connection(with: .video), connection.isVideoOrientationSupported {
      connection.videoOrientation = orientation
    }
  }

  override func removeFromSuperview() {
    super.removeFromSuperview()
    stopSession()
  }

  // -----------------------------------------------------------------------
  // MARK: Called by the module after props are applied
  // -----------------------------------------------------------------------

  func startSessionIfNeeded() {
    guard !sessionStarted else {
      // Already started; just make sure torch is applied.
      sessionQueue.async { [weak self] in self?.applyTorch() }
      return
    }
    sessionStarted = true
    sessionQueue.async { [weak self] in self?.configureAndStartSession() }
  }

  // -----------------------------------------------------------------------
  // MARK: Session setup
  // -----------------------------------------------------------------------

  private func setupPreviewLayer() {
    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.videoGravity = .resizeAspectFill
    self.layer.insertSublayer(layer, at: 0)
    previewLayer = layer
  }

  private func configureAndStartSession() {
    // 1. Find the rear camera.
    guard let device = AVCaptureDevice.default(
      .builtInWideAngleCamera,
      for: .video,
      position: .back
    ) else {
      DispatchQueue.main.async { [weak self] in
        self?.onMountError(["message": "Rear camera not available"])
      }
      return
    }
    captureDevice = device

    // 2. Create device input.
    do {
      let input = try AVCaptureDeviceInput(device: device)
      session.beginConfiguration()
      session.sessionPreset = .high

      if session.canAddInput(input) {
        session.addInput(input)
      } else {
        session.commitConfiguration()
        DispatchQueue.main.async { [weak self] in
          self?.onMountError(["message": "Cannot add camera input to session"])
        }
        return
      }

      // 3. Video data output for Vision DataMatrix detection.
      if session.canAddOutput(videoDataOutput) {
        session.addOutput(videoDataOutput)
        videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
      } else {
        session.commitConfiguration()
        DispatchQueue.main.async { [weak self] in
          self?.onMountError(["message": "Cannot add video data output to session"])
        }
        return
      }

      session.commitConfiguration()
    } catch {
      DispatchQueue.main.async { [weak self] in
        self?.onMountError(["message": error.localizedDescription])
      }
      return
    }

    // 4. Start the session.
    session.startRunning()
    applyTorch()

    DispatchQueue.main.async { [weak self] in
      self?.onCameraReady([:])
    }
  }

  private func stopSession() {
    sessionQueue.async { [weak self] in
      guard let self, self.session.isRunning else { return }
      self.session.stopRunning()
    }
  }

  // -----------------------------------------------------------------------
  // MARK: Torch
  // -----------------------------------------------------------------------

  private func applyTorch() {
    guard let device = captureDevice, device.hasTorch else { return }
    try? device.lockForConfiguration()
    device.torchMode = enableTorch ? .on : .off
    device.unlockForConfiguration()
  }

  // -----------------------------------------------------------------------
  // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
  // -----------------------------------------------------------------------

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard !isProcessingFrame else { return }
    isProcessingFrame = true

    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      isProcessingFrame = false
      return
    }

    var inputImage = CIImage(cvPixelBuffer: pixelBuffer)

    // Apply color inversion if enableInverse is true.
    if enableInverse {
      if let filter = CIFilter(name: "CIColorInvert") {
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        if let inverted = filter.outputImage {
          inputImage = inverted
        }
      }
    }

    let request = VNDetectBarcodesRequest { [weak self] request, error in
      defer { self?.isProcessingFrame = false }
      guard let self = self else { return }

      if let results = request.results as? [VNBarcodeObservation] {
        var barcodesPayload: [[String: Any]] = []
        for barcode in results {
          if barcode.symbology == .dataMatrix, let stringValue = barcode.payloadStringValue {
            let payload = self.buildBarcodePayload(barcode, stringValue: stringValue)
            barcodesPayload.append(payload)
          }
        }

        if !barcodesPayload.isEmpty {
          DispatchQueue.main.async { [weak self] in
            self?.dispatchScanResult(["barcodes": barcodesPayload])
          }
        }
      }
    }
    request.symbologies = [.dataMatrix]

    let handler = VNImageRequestHandler(ciImage: inputImage, options: [:])
    do {
      try handler.perform([request])
    } catch {
      isProcessingFrame = false
    }
  }

  // -----------------------------------------------------------------------
  // MARK: Result building & dispatch
  // -----------------------------------------------------------------------

  private func buildBarcodePayload(_ barcode: VNBarcodeObservation, stringValue: String) -> [String: Any] {
    guard let previewLayer = self.previewLayer else { return [:] }

    // Bounding Box.
    let box = barcode.boundingBox
    // Flip Y (Vision coordinates have origin at bottom-left, CALayer has it at top-left).
    let flippedBox = CGRect(
      x: box.origin.x,
      y: 1 - box.origin.y - box.size.height,
      width: box.size.width,
      height: box.size.height
    )
    let convertedBox = previewLayer.layerRectConverted(fromMetadataOutputRect: flippedBox)

    let bounds: [String: Any] = [
      "origin": ["x": convertedBox.minX, "y": convertedBox.minY],
      "size":   ["width": convertedBox.width, "height": convertedBox.height]
    ]

    // Corner points.
    let corners: [[String: CGFloat]] = [
      convertPoint(barcode.topLeft, previewLayer: previewLayer),
      convertPoint(barcode.topRight, previewLayer: previewLayer),
      convertPoint(barcode.bottomRight, previewLayer: previewLayer),
      convertPoint(barcode.bottomLeft, previewLayer: previewLayer)
    ]

    return [
      "data":         stringValue,
      "cornerPoints": corners,
      "bounds":       bounds
    ]
  }

  private func convertPoint(_ point: CGPoint, previewLayer: AVCaptureVideoPreviewLayer) -> [String: CGFloat] {
    let flippedPt = CGPoint(x: point.x, y: 1 - point.y)
    let dummyRect = CGRect(origin: flippedPt, size: .zero)
    let convertedRect = previewLayer.layerRectConverted(fromMetadataOutputRect: dummyRect)
    return ["x": convertedRect.origin.x, "y": convertedRect.origin.y]
  }

  private func dispatchScanResult(_ payload: [String: Any]) {
    onScanned(payload)
  }

  // -----------------------------------------------------------------------
  // MARK: Helpers
  // -----------------------------------------------------------------------

  private func currentVideoOrientation() -> AVCaptureVideoOrientation {
    switch UIDevice.current.orientation {
    case .landscapeLeft:  return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    case .portraitUpsideDown: return .portraitUpsideDown
    default: return .portrait
    }
  }
}
