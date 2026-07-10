import { registerWebModule, NativeModule } from 'expo';

// ReactNativeDatamatrixScannerModule is not available on the web platform.
class ReactNativeDatamatrixScannerModule extends NativeModule<{}> {}

export default registerWebModule(ReactNativeDatamatrixScannerModule, 'ReactNativeDatamatrixScannerModule');
