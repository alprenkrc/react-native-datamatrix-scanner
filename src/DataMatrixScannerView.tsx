import { Component, createRef } from 'react';
import { StyleSheet } from 'react-native';

import type {
  DataMatrixScannerProps,
  DataMatrixScanResult,
} from './DataMatrixScanner.types';
import ExpoDataMatrixScannerManager from './ExpoDataMatrixScannerManager';

type NativeScanEvent = {
  nativeEvent: {
    barcodes: DataMatrixScanResult[];
  };
};

type NativeMountErrorEvent = {
  nativeEvent: { message: string };
};

/**
 * A camera view that continuously scans for **DataMatrix** codes.
 *
 * Only the rear (back) camera is used on both platforms.
 *
 * @example
 * ```tsx
 * import { DataMatrixScannerView } from 'react-native-datamatrix-scanner';
 *
 * export default function Scanner() {
 *   return (
 *     <DataMatrixScannerView
 *       style={{ flex: 1 }}
 *       enableTorch={false}
 *       onScanned={(event) => console.log('Scanned:', event.barcodes)}
 *     />
 *   );
 * }
 * ```
 */
export default class DataMatrixScannerView extends Component<DataMatrixScannerProps> {
  private _nativeRef = createRef<any>();

  // -------------------------------------------------------------------------
  // Native event handlers
  // -------------------------------------------------------------------------

  private _onScanned = ({ nativeEvent }: NativeScanEvent) => {
    const { onScanned } = this.props;
    if (!onScanned) return;

    onScanned({
      barcodes: nativeEvent.barcodes || [],
    });
  };

  private _onCameraReady = () => {
    this.props.onCameraReady?.();
  };

  private _onMountError = ({ nativeEvent }: NativeMountErrorEvent) => {
    this.props.onMountError?.(nativeEvent);
  };

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  render() {
    const { enableTorch = false, enableInverse = false, style, ...rest } = this.props;

    return (
      <ExpoDataMatrixScannerManager
        {...rest}
        ref={this._nativeRef}
        style={[styles.fill, style]}
        enableTorch={enableTorch}
        enableInverse={enableInverse}
        onScanned={this._onScanned}
        onCameraReady={this._onCameraReady}
        onMountError={this._onMountError}
      />
    );
  }
}

const styles = StyleSheet.create({
  fill: { flex: 1 },
});
