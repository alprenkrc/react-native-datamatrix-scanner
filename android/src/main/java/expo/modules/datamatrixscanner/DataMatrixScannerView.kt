package expo.modules.datamatrixscanner

import android.annotation.SuppressLint
import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.Surface
import android.view.OrientationEventListener
import android.view.View.MeasureSpec
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.lifecycle.awaitInstance
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

// ---------------------------------------------------------------------------
// Native event payloads
// ---------------------------------------------------------------------------

/** Emitted when a DataMatrix code is successfully decoded. */
data class DataMatrixScannedEvent(
  val data: String,
  val raw: String?,
  /** Flat [x0,y0,x1,y1,x2,y2,x3,y3] in preview pixels. */
  val cornerPoints: List<Int>,
  val imageWidth: Int,
  val imageHeight: Int
)

/** Emitted when the camera session fails to start. */
data class DataMatrixMountErrorEvent(val message: String)

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

/**
 * Camera preview + DataMatrix analyzer view.
 *
 * Only the **rear** camera is used. [enableTorch] controls the device
 * flashlight while scanning.
 */
@SuppressLint("ViewConstructor")
class DataMatrixScannerView(
  context: Context,
  appContext: AppContext
) : ExpoView(context, appContext) {

  private val currentActivity
    get() = appContext.throwingActivity as AppCompatActivity

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  private val previewView = PreviewView(context).also { addView(it) }

  // -------------------------------------------------------------------------
  // Camera state
  // -------------------------------------------------------------------------

  private val scope = CoroutineScope(Dispatchers.Main)
  private var camera: Camera? = null
  private var cameraProvider: ProcessCameraProvider? = null
  private var imageAnalysisUseCase: ImageAnalysis? = null
  private var analyzer: DataMatrixAnalyzer? = null
  private var shouldRecreateCamera = false

  // -------------------------------------------------------------------------
  // Props (set from JS via module Prop definitions)
  // -------------------------------------------------------------------------

  /** Turns the device torch on or off while scanning. */
  var enableTorch: Boolean = false
    set(value) {
      if (field == value) return
      field = value
      camera?.cameraControl?.enableTorch(value)
    }

  /** Turns inverse scanning mode on or off. */
  var enableInverse: Boolean = false
    set(value) {
      if (field == value) return
      field = value
      analyzer?.enableInverse = value
    }

  // -------------------------------------------------------------------------
  // Event dispatchers
  // -------------------------------------------------------------------------

  private val onScanned by EventDispatcher<Bundle>(
    coalescingKey = { event ->
      (event.getString("data").hashCode() % Short.MAX_VALUE).toShort()
    }
  )
  private val onCameraReady by EventDispatcher<Unit>()
  private val onMountError by EventDispatcher<DataMatrixMountErrorEvent>()

  // -------------------------------------------------------------------------
  // Orientation tracking (keeps ImageAnalysis rotation in sync)
  // -------------------------------------------------------------------------

  private val orientationListener by lazy {
    object : OrientationEventListener(context) {
      override fun onOrientationChanged(orientation: Int) {
        if (orientation == ORIENTATION_UNKNOWN) return
        val rotation = when (orientation) {
          in 45 until 135 -> Surface.ROTATION_270
          in 135 until 225 -> Surface.ROTATION_180
          in 225 until 315 -> Surface.ROTATION_90
          else -> Surface.ROTATION_0
        }
        imageAnalysisUseCase?.targetRotation = rotation
      }
    }
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  init {
    orientationListener.enable()
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    orientationListener.disable()
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    previewView.measure(
      MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY)
    )
  }

  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    super.onLayout(changed, left, top, right, bottom)
    previewView.layout(0, 0, right - left, bottom - top)
  }

  /** Called by the module after every prop update cycle. */
  fun recreateCamera() {
    if (!shouldRecreateCamera) {
      // First time: always start the camera.
      shouldRecreateCamera = true
      startCamera()
    }
  }

  /** Called by the module when the view is destroyed. */
  fun cleanup() {
    try {
      scope.cancel()
    } catch (_: IllegalStateException) { /* already cancelled */ }
    cameraProvider?.unbindAll()
  }

  // -------------------------------------------------------------------------
  // Camera setup
  // -------------------------------------------------------------------------

  private fun startCamera() {
    scope.launch {
      try {
        val provider = ProcessCameraProvider.awaitInstance(appContext.throwingActivity)
        cameraProvider = provider

        val preview = Preview.Builder().build().also {
          it.surfaceProvider = previewView.surfaceProvider
        }

        // Always use the rear camera – front camera is not supported for
        // DataMatrix by either MLKit or AVFoundation on iOS.
        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        val activeAnalyzer = DataMatrixAnalyzer(previewView) { result ->
          dispatchScanResult(result)
        }.apply {
          enableInverse = this@DataMatrixScannerView.enableInverse
        }
        analyzer = activeAnalyzer

        imageAnalysisUseCase = ImageAnalysis.Builder()
          .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
          .build()
          .also { analysis ->
            analysis.setAnalyzer(
              ContextCompat.getMainExecutor(context),
              activeAnalyzer
            )
          }

        val useCases = UseCaseGroup.Builder()
          .addUseCase(preview)
          .addUseCase(imageAnalysisUseCase!!)
          .build()

        provider.unbindAll()
        camera = provider.bindToLifecycle(currentActivity, cameraSelector, useCases)

        // Apply torch state that may have been set before camera was ready.
        camera?.cameraControl?.enableTorch(enableTorch)

        onCameraReady(Unit)
      } catch (e: Exception) {
        Log.e(TAG, "Camera start failed: ${e.message}", e)
        onMountError(DataMatrixMountErrorEvent(e.message ?: "Unknown error"))
      }
    }
  }

  // -------------------------------------------------------------------------
  // Result serialization
  // -------------------------------------------------------------------------

  private fun dispatchScanResult(result: DataMatrixAnalyzer.ScanResult) {
    val density = resources.displayMetrics.density

    // View dimensions in pixels
    val viewWidth = width.toFloat()
    val viewHeight = height.toFloat()

    // Image dimensions in pixels
    val imageWidth = result.imageWidth.toFloat()
    val imageHeight = result.imageHeight.toFloat()

    var scale = 1f
    var offsetX = 0f
    var offsetY = 0f

    if (imageWidth > 0 && imageHeight > 0 && viewWidth > 0 && viewHeight > 0) {
      val rImage = imageWidth / imageHeight
      val rView = viewWidth / viewHeight

      if (rImage > rView) {
        // Image is wider than view (cropped horizontally, fits vertically)
        scale = viewHeight / imageHeight
        offsetX = (viewWidth - imageWidth * scale) / 2f
      } else {
        // Image is taller than view (cropped vertically, fits horizontally)
        scale = viewWidth / imageWidth
        offsetY = (viewHeight - imageHeight * scale) / 2f
      }
    }

    val barcodeBundles = ArrayList<Bundle>()

    for (barcode in result.barcodes) {
      val cornerBundles = ArrayList<Bundle>()
      val pts = barcode.cornerPoints
      var i = 0
      while (i < pts.size - 1) {
        val mappedX = pts[i].toFloat() * scale + offsetX
        val mappedY = pts[i + 1].toFloat() * scale + offsetY

        cornerBundles.add(Bundle().apply {
          putFloat("x", mappedX / density)
          putFloat("y", mappedY / density)
        })
        i += 2
      }

      // Compute axis-aligned bounding box.
      val xs = cornerBundles.map { it.getFloat("x") }
      val ys = cornerBundles.map { it.getFloat("y") }
      val minX = xs.minOrNull() ?: 0f
      val minY = ys.minOrNull() ?: 0f
      val maxX = xs.maxOrNull() ?: 0f
      val maxY = ys.maxOrNull() ?: 0f

      val boundsBundle = Bundle().apply {
        putParcelable("origin", Bundle().apply {
          putFloat("x", minX)
          putFloat("y", minY)
        })
        putParcelable("size", Bundle().apply {
          putFloat("width", maxX - minX)
          putFloat("height", maxY - minY)
        })
      }

      barcodeBundles.add(Bundle().apply {
        putString("data", barcode.data)
        barcode.raw?.let { putString("raw", it) }
        putParcelableArrayList("cornerPoints", cornerBundles)
        putBundle("bounds", boundsBundle)
      })
    }

    val payload = Bundle().apply {
      putParcelableArrayList("barcodes", barcodeBundles)
    }

    onScanned(payload)
  }

  companion object {
    private const val TAG = "DataMatrixScannerView"
  }
}
