package expo.modules.datamatrixscanner

import android.Manifest
import expo.modules.interfaces.permissions.Permissions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

/**
 * Expo Module definition for **expo-datamatrix-scanner**.
 *
 * Registers:
 *  - Two async permission functions (`requestCameraPermissionsAsync`,
 *    `getCameraPermissionsAsync`).
 *  - A native view ([DataMatrixScannerView]) with `enableTorch` prop and
 *    three events: `onScanned`, `onCameraReady`, `onMountError`.
 */
class DataMatrixScannerModule : Module() {

  override fun definition() = ModuleDefinition {
    Name("ExpoDataMatrixScanner")

    // -----------------------------------------------------------------------
    // Permissions
    // -----------------------------------------------------------------------

    AsyncFunction("requestCameraPermissionsAsync") { promise: Promise ->
      Permissions.askForPermissionsWithPermissionsManager(
        permissionsManager,
        promise,
        Manifest.permission.CAMERA
      )
    }

    AsyncFunction("getCameraPermissionsAsync") { promise: Promise ->
      Permissions.getPermissionsWithPermissionsManager(
        permissionsManager,
        promise,
        Manifest.permission.CAMERA
      )
    }

    // -----------------------------------------------------------------------
    // View
    // -----------------------------------------------------------------------

    View(DataMatrixScannerView::class) {
      Events("onScanned", "onCameraReady", "onMountError")

      Prop("enableTorch") { view: DataMatrixScannerView, enabled: Boolean? ->
        view.enableTorch = enabled ?: false
      }

      /**
       * Turns inverse (white on black) scanning mode on or off.
       * @default false
       */
      Prop("enableInverse") { view: DataMatrixScannerView, enabled: Boolean? ->
        view.enableInverse = enabled ?: false
      }

      /**
       * Called after all props have been applied in a render cycle.
       * Triggers camera initialization on first render and re-initialization
       * when props change.
       */
      OnViewDidUpdateProps { view: DataMatrixScannerView ->
        view.recreateCamera()
      }

      OnViewDestroys { view: DataMatrixScannerView ->
        view.cleanup()
      }
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  private val permissionsManager: Permissions
    get() = appContext.permissions ?: throw Exceptions.PermissionsModuleNotFound()
}
