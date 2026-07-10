import { requireNativeModule } from 'expo';

/**
 * The native module interface for ExpoDataMatrixScanner.
 * Exposes camera-permission helpers that can be called without rendering a view.
 */
export interface ExpoDataMatrixScannerModule {
  requestCameraPermissionsAsync(): Promise<{
    status: 'granted' | 'denied' | 'undetermined';
    granted: boolean;
    canAskAgain: boolean;
    expires: 'never' | number;
  }>;
  getCameraPermissionsAsync(): Promise<{
    status: 'granted' | 'denied' | 'undetermined';
    granted: boolean;
    canAskAgain: boolean;
    expires: 'never' | number;
  }>;
}

export default requireNativeModule<ExpoDataMatrixScannerModule>(
  'ExpoDataMatrixScanner'
);
