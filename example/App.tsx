import React, { useState, useCallback, useRef, useEffect } from 'react';
import {
  ActivityIndicator,
  Platform,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  DataMatrixScannerView,
  useDataMatrixScannerPermissions,
  type DataMatrixScanResult,
  type BoundingBox,
} from 'react-native-datamatrix-scanner';
import { SafeAreaView } from 'react-native-safe-area-context';


// ---------------------------------------------------------------------------
// Root
// ---------------------------------------------------------------------------

export default function App() {
  const [permission, requestPermission] = useDataMatrixScannerPermissions();

  if (!permission) {
    return <LoadingScreen />;
  }

  if (!permission.granted) {
    return <PermissionScreen canAskAgain={permission.canAskAgain} onRequest={requestPermission} />;
  }

  return <ScannerScreen />;
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

function LoadingScreen() {
  return (
    <View style={styles.centered}>
      <ActivityIndicator size="large" color={ACCENT} />
      <Text style={styles.loadingText}>Kamera izni kontrol ediliyor…</Text>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Permission screen
// ---------------------------------------------------------------------------

function PermissionScreen({
  canAskAgain,
  onRequest,
}: {
  canAskAgain: boolean;
  onRequest: () => void;
}) {
  return (
    <SafeAreaView style={styles.permissionContainer}>
      <View style={styles.permissionCard}>
        <Text style={styles.permissionIcon}>📷</Text>
        <Text style={styles.permissionTitle}>Kamera İzni Gerekli</Text>
        <Text style={styles.permissionBody}>
          DataMatrix barkodlarını taramak için kamera iznine ihtiyaç var.
        </Text>
        {canAskAgain ? (
          <Pressable style={styles.primaryBtn} onPress={onRequest}>
            <Text style={styles.primaryBtnText}>İzin Ver</Text>
          </Pressable>
        ) : (
          <Text style={styles.deniedText}>
            İzin kalıcı olarak reddedildi. Lütfen Ayarlar'dan kamera iznini etkinleştirin.
          </Text>
        )}
      </View>
    </SafeAreaView>
  );
}

// ---------------------------------------------------------------------------
// Scanner screen
// ---------------------------------------------------------------------------

function ScannerScreen() {
  const [torch, setTorch] = useState(false);
  const [inverse, setInverse] = useState(false);
  const [cameraReady, setCameraReady] = useState(false);
  const [mountError, setMountError] = useState<string | null>(null);
  const [lastResult, setLastResult] = useState<DataMatrixScanResult | null>(null);
  const [scanCount, setScanCount] = useState(0);
  const [activeBounds, setActiveBounds] = useState<BoundingBox | null>(null);
  const timeoutRef = useRef<any>(null);

  const handleScanned = useCallback((event: any) => {
    const result = event.barcodes ? event.barcodes[0] : event;
    if (!result) return;
    setLastResult(result);
    setScanCount((c) => c + 1);
    setActiveBounds(result.bounds);

    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
    timeoutRef.current = setTimeout(() => {
      setActiveBounds(null);
    }, 1000);
  }, []);

  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  const handleCameraReady = useCallback(() => {
    setCameraReady(true);
    setMountError(null);
  }, []);

  const handleMountError = useCallback((e: { message: string }) => {
    setMountError(e.message);
    setCameraReady(false);
  }, []);

  return (
    <View style={styles.root}>
      <StatusBar barStyle="light-content" />

      {/* ── Camera Preview ── */}
      <DataMatrixScannerView
        style={styles.camera}
        enableTorch={torch}
        enableInverse={inverse}
        onScanned={handleScanned}
        onCameraReady={handleCameraReady}
        onMountError={handleMountError}
      />

      {/* ── Bounding Box Overlay ── */}
      {activeBounds && (
        <View
          pointerEvents="none"
          style={{
            position: 'absolute',
            left: activeBounds.origin.x,
            top: activeBounds.origin.y,
            width: activeBounds.size.width,
            height: activeBounds.size.height,
            borderWidth: 3,
            borderColor: '#00FF00',
            backgroundColor: 'rgba(0, 255, 0, 0.25)',
            borderRadius: 8,
          }}
        />
      )}

      {/* ── Top HUD ── */}
      <SafeAreaView style={styles.hudTop} pointerEvents="box-none">
        <View style={styles.hudTopInner}>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>
              {mountError ? '⚠️ Hata' : cameraReady ? '🟢 Hazır' : '⏳ Başlatılıyor'}
            </Text>
          </View>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>#{scanCount} tarama</Text>
          </View>

          {/* Controls wrapper */}
          <View style={{ marginLeft: 'auto', flexDirection: 'row', gap: 8 }}>
            {/* Inverse mode toggle */}
            <Pressable
              style={[styles.torchBtn, inverse && styles.torchBtnActive]}
              onPress={() => setInverse((v) => !v)}
            >
              <Text style={styles.torchIcon}>{inverse ? '🌗' : '🌘'}</Text>
            </Pressable>

            {/* Torch toggle */}
            <Pressable
              style={[styles.torchBtn, torch && styles.torchBtnActive]}
              onPress={() => setTorch((v) => !v)}
            >
              <Text style={styles.torchIcon}>{torch ? '🔦' : '💡'}</Text>
            </Pressable>
          </View>
        </View>
      </SafeAreaView>

      {/* ── Scan target frame ── */}
      <View style={styles.frameOuter} pointerEvents="none">
        <View style={styles.frameBox}>
          <View style={[styles.corner, styles.cornerTL]} />
          <View style={[styles.corner, styles.cornerTR]} />
          <View style={[styles.corner, styles.cornerBL]} />
          <View style={[styles.corner, styles.cornerBR]} />
        </View>
        <Text style={styles.frameHint}>DataMatrix kodu çerçeveye getirin</Text>
      </View>

      {/* ── Mount error banner ── */}
      {mountError && (
        <View style={styles.errorBanner}>
          <Text style={styles.errorBannerText}>⚠️ {mountError}</Text>
        </View>
      )}

      {/* ── Result overlay ── */}
      <SafeAreaView style={styles.resultContainer} pointerEvents="none">
        {lastResult ? (
          <ScrollView
            style={styles.resultCard}
            contentContainerStyle={styles.resultCardContent}
            showsVerticalScrollIndicator={false}
          >
            <Text style={styles.resultTitle}>✅ DataMatrix Okundu</Text>

            <ResultRow label="Veri" value={lastResult.data} highlight />

            {lastResult.raw && lastResult.raw !== lastResult.data && (
              <ResultRow label="Ham" value={lastResult.raw} />
            )}

            {lastResult.cornerPoints && (
              <ResultRow
                label="Köşe Noktaları"
                value={lastResult.cornerPoints
                  .map((p) => `(${p.x.toFixed(1)}, ${p.y.toFixed(1)})`)
                  .join('  ')}
              />
            )}

            {lastResult.bounds && (
              <ResultRow
                label="Bounding Box"
                value={
                  `x:${lastResult.bounds.origin?.x?.toFixed(1) ?? '0'}  ` +
                  `y:${lastResult.bounds.origin?.y?.toFixed(1) ?? '0'}  ` +
                  `w:${lastResult.bounds.size?.width?.toFixed(1) ?? '0'}  ` +
                  `h:${lastResult.bounds.size?.height?.toFixed(1) ?? '0'}`
                }
              />
            )}
          </ScrollView>
        ) : (
          <View style={styles.waitingCard}>
            <Text style={styles.waitingText}>Henüz barkod okunmadı</Text>
          </View>
        )}
      </SafeAreaView>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Helper component
// ---------------------------------------------------------------------------

function ResultRow({
  label,
  value,
  highlight = false,
}: {
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <View style={styles.resultRow}>
      <Text style={styles.resultLabel}>{label}</Text>
      <Text style={[styles.resultValue, highlight && styles.resultValueHighlight]}>
        {value}
      </Text>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Constants & Styles
// ---------------------------------------------------------------------------

const ACCENT = '#00C6FF';
const CORNER_SIZE = 24;
const CORNER_THICKNESS = 3;

const styles = StyleSheet.create({
  // ── Generic ──
  root: { flex: 1, backgroundColor: '#000' },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#0a0a0a' },
  loadingText: { color: '#aaa', marginTop: 12, fontSize: 14 },

  // ── Permission ──
  permissionContainer: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  permissionCard: {
    backgroundColor: '#1a1a1a',
    borderRadius: 20,
    padding: 32,
    alignItems: 'center',
    maxWidth: 360,
    width: '100%',
    borderWidth: 1,
    borderColor: '#333',
  },
  permissionIcon: { fontSize: 56, marginBottom: 16 },
  permissionTitle: { color: '#fff', fontSize: 22, fontWeight: '700', marginBottom: 12 },
  permissionBody: {
    color: '#999',
    fontSize: 15,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: 28,
  },
  primaryBtn: {
    backgroundColor: ACCENT,
    borderRadius: 12,
    paddingVertical: 14,
    paddingHorizontal: 40,
  },
  primaryBtnText: { color: '#000', fontSize: 16, fontWeight: '700' },
  deniedText: { color: '#f66', fontSize: 14, textAlign: 'center', lineHeight: 20 },

  // ── Camera ──
  camera: { ...StyleSheet.absoluteFill },

  // ── Top HUD ──
  hudTop: { position: 'absolute', top: 0, left: 0, right: 0 },
  hudTopInner: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: Platform.OS === 'android' ? StatusBar.currentHeight ?? 0 + 8 : 8,
    gap: 8,
  },
  badge: {
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderRadius: 20,
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.15)',
  },
  badgeText: { color: '#fff', fontSize: 13, fontWeight: '600' },
  torchBtn: {
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderRadius: 24,
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.15)',
  },
  torchBtnActive: {
    backgroundColor: 'rgba(255,200,0,0.3)',
    borderColor: '#ffc800',
  },
  torchIcon: { fontSize: 22 },

  // ── Scan frame ──
  frameOuter: {
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    alignItems: 'center',
    justifyContent: 'center',
  },
  frameBox: {
    width: 220,
    height: 220,
    position: 'relative',
  },
  corner: {
    position: 'absolute',
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderColor: ACCENT,
  },
  cornerTL: { top: 0, left: 0, borderTopWidth: CORNER_THICKNESS, borderLeftWidth: CORNER_THICKNESS, borderTopLeftRadius: 4 },
  cornerTR: { top: 0, right: 0, borderTopWidth: CORNER_THICKNESS, borderRightWidth: CORNER_THICKNESS, borderTopRightRadius: 4 },
  cornerBL: { bottom: 0, left: 0, borderBottomWidth: CORNER_THICKNESS, borderLeftWidth: CORNER_THICKNESS, borderBottomLeftRadius: 4 },
  cornerBR: { bottom: 0, right: 0, borderBottomWidth: CORNER_THICKNESS, borderRightWidth: CORNER_THICKNESS, borderBottomRightRadius: 4 },
  frameHint: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: 13,
    marginTop: 16,
    textAlign: 'center',
  },

  // ── Error banner ──
  errorBanner: {
    position: 'absolute',
    top: 100,
    left: 16,
    right: 16,
    backgroundColor: 'rgba(200,0,0,0.85)',
    borderRadius: 10,
    padding: 12,
  },
  errorBannerText: { color: '#fff', fontSize: 14, textAlign: 'center' },

  // ── Result card ──
  resultContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
  },
  resultCard: {
    backgroundColor: 'rgba(10,10,20,0.92)',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: 260,
    borderTopWidth: 1,
    borderColor: ACCENT,
  },
  resultCardContent: { padding: 20, gap: 10 },
  resultTitle: {
    color: ACCENT,
    fontSize: 15,
    fontWeight: '700',
    marginBottom: 4,
  },
  resultRow: { gap: 2 },
  resultLabel: { color: '#666', fontSize: 11, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5 },
  resultValue: { color: '#ccc', fontSize: 14, lineHeight: 20 },
  resultValueHighlight: { color: '#fff', fontSize: 16, fontWeight: '700' },

  waitingCard: {
    backgroundColor: 'rgba(10,10,20,0.75)',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    alignItems: 'center',
  },
  waitingText: { color: '#555', fontSize: 14 },
});
