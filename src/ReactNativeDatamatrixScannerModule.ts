import { NativeModule, requireNativeModule } from 'expo';

declare class ReactNativeDatamatrixScannerModule extends NativeModule<{}> {}

export default requireNativeModule<ReactNativeDatamatrixScannerModule>('ReactNativeDatamatrixScanner');
