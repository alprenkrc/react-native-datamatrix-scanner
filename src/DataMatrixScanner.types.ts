import type { PermissionResponse } from 'expo';
import type { ViewProps } from 'react-native';

// ---------------------------------------------------------------------------
// Scan result
// ---------------------------------------------------------------------------

export type Point = {
  x: number;
  y: number;
};

export type Size = {
  width: number;
  height: number;
};

export type BoundingBox = {
  origin: Point;
  size: Size;
};

/**
 * Result emitted by the scanner each time a DataMatrix code is detected.
 */
export type DataMatrixScanResult = {
  /** Decoded text content of the DataMatrix code. */
  data: string;
  /**
   * Raw byte string of the DataMatrix code. May differ from `data` when the
   * payload contains non-UTF8 bytes.
   */
  raw?: string;
  /**
   * Four corner points of the detected symbol in the **preview coordinate
   * space** (origin = top-left of the camera preview).
   */
  cornerPoints: Point[];
  /** Axis-aligned bounding box derived from the corner points. */
  bounds: BoundingBox;
};

export type DataMatrixScanEvent = {
  barcodes: DataMatrixScanResult[];
};

// ---------------------------------------------------------------------------
// View props
// ---------------------------------------------------------------------------

export type DataMatrixScannerProps = ViewProps & {
  /**
   * Whether to turn on the device torch (flashlight) while scanning.
   * @default false
   */
  enableTorch?: boolean;

  /**
   * Whether to invert color luminance to scan inverted (white-on-black) barcodes.
   * @default false
   */
  enableInverse?: boolean;

  /**
   * Callback invoked every time a frame is scanned with DataMatrix codes.
   */
  onScanned?: (event: DataMatrixScanEvent) => void;

  /**
   * Callback invoked when the camera session is ready and the preview has
   * started.
   */
  onCameraReady?: () => void;

  /**
   * Callback invoked when the camera fails to start.
   */
  onMountError?: (error: { message: string }) => void;
};

// ---------------------------------------------------------------------------
// Re-export permissions type for convenience
// ---------------------------------------------------------------------------

export type { PermissionResponse };
