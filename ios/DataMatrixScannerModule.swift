// DataMatrixScannerModule.swift
// react-native-datamatrix-scanner
//
// Expo Module definition: registers the native view and camera-permission
// helpers for the iOS platform.

import AVFoundation
import ExpoModulesCore

public final class DataMatrixScannerModule: Module {

  public func definition() -> ModuleDefinition {
    Name("ExpoDataMatrixScanner")

    // -----------------------------------------------------------------------
    // MARK: – Permission helpers (Native Swift AVFoundation)
    // -----------------------------------------------------------------------

    AsyncFunction("getCameraPermissionsAsync") { (promise: Promise) in
      let status = AVCaptureDevice.authorizationStatus(for: .video)
      var statusString = "undetermined"
      var granted = false
      
      switch status {
      case .authorized:
        statusString = "granted"
        granted = true
      case .denied, .restricted:
        statusString = "denied"
      case .notDetermined:
        statusString = "undetermined"
      @unknown default:
        statusString = "undetermined"
      }
      
      promise.resolve([
        "status": statusString,
        "granted": granted,
        "canAskAgain": status != .denied && status != .restricted,
        "expires": "never"
      ])
    }

    AsyncFunction("requestCameraPermissionsAsync") { (promise: Promise) in
      AVCaptureDevice.requestAccess(for: .video) { granted in
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var statusString = "undetermined"
        
        switch status {
        case .authorized:
          statusString = "granted"
        case .denied, .restricted:
          statusString = "denied"
        case .notDetermined:
          statusString = "undetermined"
        @unknown default:
          statusString = "undetermined"
        }
        
        promise.resolve([
          "status": statusString,
          "granted": granted,
          "canAskAgain": status != .denied && status != .restricted,
          "expires": "never"
        ])
      }
    }

    // -----------------------------------------------------------------------
    // MARK: – View
    // -----------------------------------------------------------------------

    View(DataMatrixScannerView.self) {
      Events("onScanned", "onCameraReady", "onMountError")

      /// Turns the device torch on or off.
      Prop("enableTorch") { (view: DataMatrixScannerView, enabled: Bool?) in
        view.enableTorch = enabled ?? false
      }

      /// Turns inverse scanning mode on or off.
      Prop("enableInverse") { (view: DataMatrixScannerView, enabled: Bool?) in
        view.enableInverse = enabled ?? false
      }

      /// Called after all props have been applied.
      /// Starts the AVCaptureSession on first render.
      OnViewDidUpdateProps { (view: DataMatrixScannerView) in
        view.startSessionIfNeeded()
      }
    }
  }
}
