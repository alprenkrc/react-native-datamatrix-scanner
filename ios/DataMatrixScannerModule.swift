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

/// Minimal permission requester for camera-only access.
/// Mirrors the pattern used in expo-camera's CameraPermissionRequester.
private class CameraOnlyPermissionRequester: NSObject, EXPermissionsRequester {

  static func permissionType() -> String { "camera" }

  func requestPermissions(
    resolver resolve: @escaping EXPromiseResolveBlock,
    rejecter reject: @escaping EXPromiseRejectBlock
  ) {
    AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
      self?.getPermissions(resolver: resolve, rejecter: reject)
    }
  }

  func getPermissions(
    resolver resolve: EXPromiseResolveBlock,
    rejecter reject: EXPromiseRejectBlock
  ) {
    var permissionStatus: EXPermissionStatus

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      permissionStatus = EXPermissionStatusGranted
    case .denied, .restricted:
      permissionStatus = EXPermissionStatusDenied
    default:
      permissionStatus = EXPermissionStatusUndetermined
    }

    resolve([
      "status":       EXPermissionsMethodsDelegate.permissionString(for: permissionStatus) as Any,
      "granted":      permissionStatus == EXPermissionStatusGranted,
      "canAskAgain":  AVCaptureDevice.authorizationStatus(for: .video) != .denied,
      "expires":      "never"
    ])
  }
}
