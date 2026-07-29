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
    // MARK: – Permission helpers
    // -----------------------------------------------------------------------

    OnCreate {
      let permissionsManager = self.appContext?.permissions
      EXPermissionsMethodsDelegate.register(
        [CameraOnlyPermissionRequester()],
        withPermissionsManager: permissionsManager
      )
    }

    AsyncFunction("getCameraPermissionsAsync") { (promise: Promise) in
      EXPermissionsMethodsDelegate.getPermissionWithPermissionsManager(
        self.appContext?.permissions,
        withRequester: CameraOnlyPermissionRequester.self,
        resolve: promise.legacyResolver,
        reject: promise.legacyRejecter
      )
    }

    AsyncFunction("requestCameraPermissionsAsync") { (promise: Promise) in
      EXPermissionsMethodsDelegate.askForPermission(
        withPermissionsManager: self.appContext?.permissions,
        withRequester: CameraOnlyPermissionRequester.self,
        resolve: promise.legacyResolver,
        reject: promise.legacyRejecter
      )
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

// ---------------------------------------------------------------------------
// MARK: – Camera permission requester
// ---------------------------------------------------------------------------

private class CameraOnlyPermissionRequester: NSObject, EXPermissionsRequester {

  static func permissionType() -> String { "camera" }

  func getPermissions() -> [AnyHashable : Any]? {
    var statusString = "undetermined"
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    if status == .authorized {
      statusString = "granted"
    } else if status == .denied || status == .restricted {
      statusString = "denied"
    }

    return [
      "status": statusString,
      "granted": status == .authorized,
      "canAskAgain": status != .denied,
      "expires": "never"
    ]
  }

  func requestPermissions(
    resolver resolve: @escaping EXPromiseResolveBlock,
    rejecter reject: @escaping EXPromiseRejectBlock
  ) {
    AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
      resolve(self?.getPermissions())
    }
  }
}
