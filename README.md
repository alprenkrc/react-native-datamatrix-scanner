# react-native-datamatrix-scanner

A high-performance, lightweight **Expo & React Native** module for scanning **DataMatrix (2D)** barcodes using the device's rear camera. 

Powered by **CameraX + ML Kit** on Android and **AVFoundation + Vision Framework + Core Image** on iOS. Built from the ground up to support modern Expo Autolinking (Expo SDK 50+).

---

## Key Features

*   **⚡ Blazing Fast Detection:** Uses Google's ML Kit on Android and Apple's native Vision framework on iOS.
*   **🌓 Inverse Mode Support:** Scan negative/inverted barcodes (white codes on a dark background) on both iOS and Android.
*   **🎯 Screen-Aligned Bounding Boxes:** Get actual screen coordinates for detected barcode corners and bounds, mapped perfectly to portrait and landscape viewports.
*   **🔦 Torch Control:** Easy flashlight toggle prop.
*   **🔒 Native Permissions:** Built-in async methods and React Hook for checking and requesting camera permissions.

---

## Installation

Run the following command in your project directory:

```bash
npx expo install react-native-datamatrix-scanner
```

### Config Plugin Integration

Add the module plugin to your `app.json` or `app.config.js`:

```json
{
  "expo": {
    "plugins": ["react-native-datamatrix-scanner"]
  }
}
```

### iOS Configuration (`Info.plist`)

You must add a camera usage description to your `app.json` under `ios.infoPlist`:

```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "NSCameraUsageDescription": "This app uses the camera to scan DataMatrix codes."
      }
    }
  }
}
```

---

## Usage Example

Here is a full example showing permission handling, the live scanner, bounding box coordinates, and inverse mode toggles.

```tsx
import React, { useState } from 'react';
import { StyleSheet, Text, View, Pressable, SafeAreaView } from 'react-native';
import {
  DataMatrixScannerView,
  useDataMatrixScannerPermissions,
  type DataMatrixScanResult,
} from 'react-native-datamatrix-scanner';

export default function App() {
  const [permission, requestPermission] = useDataMatrixScannerPermissions();
  const [torch, setTorch] = useState(false);
  const [inverse, setInverse] = useState(false);
  const [lastScan, setLastScan] = useState<string | null>(null);

  if (!permission) {
    return <View style={styles.center}><Text>Loading permissions...</Text></View>;
  }

  if (!permission.granted) {
    return (
      <View style={styles.center}>
        <Text style={styles.text} onPress={requestPermission}>
          Grant camera permission
        </Text>
      </View>
    );
  }

  const handleScanned = (result: DataMatrixScanResult) => {
    setLastScan(result.data);
    console.log('Decoded data:', result.data);
    console.log('Bounds on screen (dp):', result.bounds);
    console.log('4 Corner Points (dp):', result.cornerPoints);
  };

  return (
    <View style={styles.container}>
      <DataMatrixScannerView
        style={styles.scanner}
        enableTorch={torch}
        enableInverse={inverse}
        onScanned={handleScanned}
        onCameraReady={() => console.log('Camera ready!')}
        onMountError={(e) => console.error('Mount error:', e.message)}
      />

      {/* Control Buttons Overlay */}
      <SafeAreaView style={styles.hud} pointerEvents="box-none">
        <View style={styles.btnRow}>
          {/* Inverse Mode Toggle */}
          <Pressable
            style={[styles.btn, inverse && styles.btnActive]}
            onPress={() => setInverse(!inverse)}
          >
            <Text style={styles.btnText}>{inverse ? 'Invert ON 🌗' : 'Invert OFF 🌘'}</Text>
          </Pressable>

          {/* Torch Toggle */}
          <Pressable
            style={[styles.btn, torch && styles.btnActive]}
            onPress={() => setTorch(!torch)}
          >
            <Text style={styles.btnText}>{torch ? 'Torch ON 🔦' : 'Torch OFF 💡'}</Text>
          </Pressable>
        </View>
      </SafeAreaView>

      {/* Result Display Overlay */}
      {lastScan && (
        <View style={styles.resultContainer}>
          <Text style={styles.resultText}>Result: {lastScan}</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  scanner:   { flex: 1 },
  center:    { flex: 1, alignItems: 'center', justifyContent: 'center' },
  text:      { fontSize: 16, color: '#00C6FF', fontWeight: 'bold' },
  hud: {
    position: 'absolute',
    top: 40,
    left: 20,
    right: 20,
  },
  btnRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  btn: {
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderRadius: 8,
    padding: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  btnActive: {
    backgroundColor: 'rgba(0, 198, 255, 0.3)',
    borderColor: '#00C6FF',
  },
  btnText: { color: '#fff', fontWeight: 'bold' },
  resultContainer: {
    position: 'absolute',
    bottom: 50,
    left: 20,
    right: 20,
    backgroundColor: 'rgba(0,0,0,0.85)',
    borderRadius: 10,
    padding: 15,
    borderWidth: 1,
    borderColor: '#00C6FF',
  },
  resultText: { color: '#fff', fontSize: 16, textAlign: 'center' },
});
```

---

## API Reference

### `<DataMatrixScannerView>`

| Prop | Type | Default | Description |
|:---|:---|:---|:---|
| `enableTorch` | `boolean` | `false` | Turns the device flashlight on/off. |
| `enableInverse` | `boolean` | `false` | Enables color inversion on raw frames to allow scanning white barcodes on dark backgrounds. |
| `onScanned` | `(result: DataMatrixScanResult) => void` | `undefined` | Callback triggered when a DataMatrix is successfully scanned (throttled). |
| `onCameraReady` | `() => void` | `undefined` | Callback invoked once the camera starts and preview view is ready. |
| `onMountError` | `(error: { message: string }) => void` | `undefined` | Callback invoked if camera initialization fails (e.g. permission denied). |

### Data Structures

#### `DataMatrixScanResult`

```typescript
type DataMatrixScanResult = {
  data: string;              // Decoded barcode text
  raw?: string;              // Raw bytes string (Android only, if different from UTF-8 data)
  cornerPoints: Point[];     // 4 corners of the code mapped to view screen points
  bounds: BoundingBox;       // Axis-aligned bounding box coordinates
  imageWidth?: number;       // Camera frame analysis width (dp, Android only)
  imageHeight?: number;      // Camera frame analysis height (dp, Android only)
};
```

#### `BoundingBox`

```typescript
type BoundingBox = {
  origin: { x: number; y: number };
  size: { width: number; height: number };
};
```

---

## Permission Helpers

This module exports standard asynchronous permission helpers and a React Hook for managing camera access:

```typescript
import {
  getCameraPermissionsAsync,
  requestCameraPermissionsAsync,
  useDataMatrixScannerPermissions,
} from 'react-native-datamatrix-scanner';
```

### Methods

*   **`getCameraPermissionsAsync(): Promise<PermissionResponse>`**: Check existing permissions without prompting the user.
*   **`requestCameraPermissionsAsync(): Promise<PermissionResponse>`**: Request permission to access the device camera.
*   **`useDataMatrixScannerPermissions()`**: React hook that returns `[permission, requestPermission]`.

---

## Platform Engine Specifications

| Feature | Android | iOS |
|:---|:---|:---|
| **Engine** | Google ML Kit (Barcode Scanning) | Apple Vision Framework |
| **Inversion (Inverse Mode)** | Grayscale luminance inversion (`YUV_420_888`) | GPU Core Image color inversion (`CIColorInvert`) |
| **Bounding Box Mapping** | Transformed viewport aspect ratio | Native CALayer coordinate mapping |
| **Min SDK** | API 24 (Android 7.0) | iOS 15.0 |

---

## License

MIT
