package expo.modules.datamatrixscanner

import android.util.Log
import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.view.PreviewView
import androidx.camera.view.TransformExperimental
import androidx.camera.view.transform.CoordinateTransform
import androidx.camera.view.transform.ImageProxyTransformFactory
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage

/**
 * CameraX [ImageAnalysis.Analyzer] that restricts scanning to
 * **DataMatrix** format only.
 *
 * Coordinates are mapped to the PreviewView space natively.
 */
@OptIn(ExperimentalGetImage::class, TransformExperimental::class)
class DataMatrixAnalyzer(
  private val previewView: PreviewView?,
  private val onResult: (ScanResult) -> Unit
) : ImageAnalysis.Analyzer {

  var enableInverse: Boolean = false

  /** Barcode data model. */
  data class BarcodeData(
    val data: String,
    val raw: String?,
    val cornerPoints: List<Int>
  )

  /** Result model passed to [onResult]. */
  data class ScanResult(
    val barcodes: List<BarcodeData>,
    val imageWidth: Int,
    val imageHeight: Int
  )

  private val scanner = BarcodeScanning.getClient(
    BarcodeScannerOptions.Builder()
      .setBarcodeFormats(Barcode.FORMAT_DATA_MATRIX)
      .build()
  )

  override fun analyze(imageProxy: ImageProxy) {
    val mediaImage = imageProxy.image
    if (mediaImage == null) {
      imageProxy.close()
      return
    }

    val rotationDegrees = imageProxy.imageInfo.rotationDegrees

    val image = if (enableInverse) {
      val width = imageProxy.width
      val height = imageProxy.height
      val yPlane = imageProxy.planes[0]
      val yBuffer = yPlane.buffer
      val rowStride = yPlane.rowStride

      val nv21Bytes = ByteArray(width * height + (width * height) / 2)

      // Copy Y channel and invert (255 - y)
      var outIndex = 0
      for (row in 0 until height) {
        yBuffer.position(row * rowStride)
        for (col in 0 until width) {
          val yVal = yBuffer.get().toInt() and 0xFF
          nv21Bytes[outIndex++] = (255 - yVal).toByte()
        }
      }

      // Fill U/V channels with neutral grey (128)
      nv21Bytes.fill(128.toByte(), width * height, nv21Bytes.size)

      InputImage.fromByteArray(
        nv21Bytes,
        width,
        height,
        rotationDegrees,
        InputImage.IMAGE_FORMAT_NV21
      )
    } else {
      InputImage.fromMediaImage(mediaImage, rotationDegrees)
    }

    // MLKit returns coordinates in the post-rotation space, so swap
    // width/height when the frame is rotated 90° or 270°.
    val isRotated = rotationDegrees == 90 || rotationDegrees == 270
    val effectiveWidth = if (isRotated) imageProxy.height else imageProxy.width
    val effectiveHeight = if (isRotated) imageProxy.width else imageProxy.height

    scanner.process(image)
      .addOnSuccessListener { barcodes ->
        if (barcodes.isEmpty()) return@addOnSuccessListener

        val list = ArrayList<BarcodeData>()
        for (barcode in barcodes) {
          val data = barcode.rawValue ?: barcode.rawBytes?.let { String(it) } ?: continue
          val raw = barcode.rawBytes?.let { String(it) }
          val cornerPoints = barcode.cornerPoints?.let { points ->
            IntArray(points.size * 2).apply {
              points.forEachIndexed { i, p ->
                this[i * 2] = p.x
                this[i * 2 + 1] = p.y
              }
            }.toList()
          } ?: emptyList()
          list.add(BarcodeData(data, raw, cornerPoints))
        }

        if (list.isNotEmpty()) {
          onResult(
            ScanResult(
              barcodes = list,
              imageWidth = effectiveWidth,
              imageHeight = effectiveHeight
            )
          )
        }
      }
      .addOnFailureListener { e ->
        Log.d(TAG, "DataMatrix scanning failed: ${e.message}")
      }
      .addOnCompleteListener {
        imageProxy.close()
      }
  }

  companion object {
    private const val TAG = "DataMatrixAnalyzer"
  }
}
