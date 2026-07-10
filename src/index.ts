import { createPermissionHook, type PermissionResponse } from 'expo';

import ExpoDataMatrixScanner from './ExpoDataMatrixScanner';

export { default as DataMatrixScannerView } from './DataMatrixScannerView';
export type {
  DataMatrixScanResult,
  DataMatrixScanEvent,
  DataMatrixScannerProps,
  Point,
  Size,
  BoundingBox,
} from './DataMatrixScanner.types';

// ---------------------------------------------------------------------------
// Permission helpers
// ---------------------------------------------------------------------------

/**
 * Checks whether the app already has permission to access the camera.
 */
export async function getCameraPermissionsAsync(): Promise<PermissionResponse> {
  return ExpoDataMatrixScanner.getCameraPermissionsAsync() as Promise<PermissionResponse>;
}

/**
 * Asks the user to grant camera permission.
 * On iOS this requires `NSCameraUsageDescription` in Info.plist.
 */
export async function requestCameraPermissionsAsync(): Promise<PermissionResponse> {
  return ExpoDataMatrixScanner.requestCameraPermissionsAsync() as Promise<PermissionResponse>;
}

/**
 * React hook for camera permissions.
 *
 * @example
 * ```ts
 * const [status, requestPermission] = useDataMatrixScannerPermissions();
 * ```
 */
export const useDataMatrixScannerPermissions = createPermissionHook({
  getMethod: getCameraPermissionsAsync,
  requestMethod: requestCameraPermissionsAsync,
});
