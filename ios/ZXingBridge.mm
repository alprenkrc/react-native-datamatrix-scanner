// ZXingBridge.mm
// react-native-datamatrix-scanner

#import "ZXingBridge.h"
#include "ReadBarcode.h"
#include "ReaderOptions.h"
#include "Barcode.h"
#include "ImageView.h"
#include <vector>

@implementation ZXingBarcodeResult
@end

@implementation ZXingBridge

+ (NSArray<ZXingBarcodeResult *> *)readDataMatrixFromPixelBuffer:(CVPixelBufferRef)pixelBuffer enableInverse:(BOOL)enableInverse {
  if (!pixelBuffer) return @[];

  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
  void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);

  if (!baseAddress) {
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return @[];
  }

  OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  std::vector<uint8_t> lumaBuffer(width * height);

  if (pixelFormat == kCVPixelFormatType_32BGRA) {
    const uint8_t *src = (const uint8_t *)baseAddress;
    for (size_t y = 0; y < height; ++y) {
      const uint8_t *rowSrc = src + y * bytesPerRow;
      uint8_t *rowDst = lumaBuffer.data() + y * width;
      for (size_t x = 0; x < width; ++x) {
        uint8_t b = rowSrc[x * 4];
        uint8_t g = rowSrc[x * 4 + 1];
        uint8_t r = rowSrc[x * 4 + 2];
        uint8_t luma = (r * 77 + g * 150 + b * 29) >> 8;
        rowDst[x] = enableInverse ? (255 - luma) : luma;
      }
    }
  } else if (pixelFormat == kCVPixelFormatType_32RGBA) {
    const uint8_t *src = (const uint8_t *)baseAddress;
    for (size_t y = 0; y < height; ++y) {
      const uint8_t *rowSrc = src + y * bytesPerRow;
      uint8_t *rowDst = lumaBuffer.data() + y * width;
      for (size_t x = 0; x < width; ++x) {
        uint8_t r = rowSrc[x * 4];
        uint8_t g = rowSrc[x * 4 + 1];
        uint8_t b = rowSrc[x * 4 + 2];
        uint8_t luma = (r * 77 + g * 150 + b * 29) >> 8;
        rowDst[x] = enableInverse ? (255 - luma) : luma;
      }
    }
  } else if (pixelFormat == kCVPixelFormatType_32ARGB) {
    const uint8_t *src = (const uint8_t *)baseAddress;
    for (size_t y = 0; y < height; ++y) {
      const uint8_t *rowSrc = src + y * bytesPerRow;
      uint8_t *rowDst = lumaBuffer.data() + y * width;
      for (size_t x = 0; x < width; ++x) {
        uint8_t r = rowSrc[x * 4 + 1];
        uint8_t g = rowSrc[x * 4 + 2];
        uint8_t b = rowSrc[x * 4 + 3];
        uint8_t luma = (r * 77 + g * 150 + b * 29) >> 8;
        rowDst[x] = enableInverse ? (255 - luma) : luma;
      }
    }
  } else if (CVPixelBufferIsPlanar(pixelBuffer)) {
    const uint8_t *src = (const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    size_t planeBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    for (size_t y = 0; y < height; ++y) {
      const uint8_t *rowSrc = src + y * planeBytesPerRow;
      uint8_t *rowDst = lumaBuffer.data() + y * width;
      for (size_t x = 0; x < width; ++x) {
        uint8_t luma = rowSrc[x];
        rowDst[x] = enableInverse ? (255 - luma) : luma;
      }
    }
  } else {
    const uint8_t *src = (const uint8_t *)baseAddress;
    for (size_t y = 0; y < height; ++y) {
      const uint8_t *rowSrc = src + y * bytesPerRow;
      uint8_t *rowDst = lumaBuffer.data() + y * width;
      for (size_t x = 0; x < width; ++x) {
        uint8_t luma = (x < bytesPerRow) ? rowSrc[x] : 0;
        rowDst[x] = enableInverse ? (255 - luma) : luma;
      }
    }
  }

  ZXing::ImageView imageView(
    lumaBuffer.data(),
    static_cast<int>(width),
    static_cast<int>(height),
    ZXing::ImageFormat::Lum,
    static_cast<int>(width)
  );

  ZXing::ReaderOptions options;
  options.setFormats(ZXing::BarcodeFormat::DataMatrix);
  options.setTryHarder(true);
  options.setTryRotate(true);
  options.setTryInvert(true);
  options.setTryDownscale(true);
  options.setTryDenoise(true);
  options.setTextMode(ZXing::TextMode::Plain);

  auto barcodes = ZXing::ReadBarcodes(imageView, options);

  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

  NSMutableArray<ZXingBarcodeResult *> *results = [NSMutableArray array];

  for (const auto &barcode : barcodes) {
    if (!barcode.isValid()) continue;

    ZXingBarcodeResult *res = [[ZXingBarcodeResult alloc] init];
    res.text = [NSString stringWithUTF8String:barcode.text().c_str()] ?: @"";

    // Extract raw bytes preserving ISO-8859-1 (Latin-1) encoding for FNC1
    const auto &bytes = barcode.bytes();
    if (!bytes.empty()) {
      NSData *rawBytes = [NSData dataWithBytes:bytes.data() length:bytes.size()];
      res.raw = [[NSString alloc] initWithData:rawBytes encoding:NSISOLatin1StringEncoding];
    } else {
      res.raw = res.text;
    }

    res.imageWidth = (NSInteger)width;
    res.imageHeight = (NSInteger)height;

    const auto pos = barcode.position();
    NSDictionary *p0 = @{@"x": @(pos[0].x), @"y": @(pos[0].y)};
    NSDictionary *p1 = @{@"x": @(pos[1].x), @"y": @(pos[1].y)};
    NSDictionary *p2 = @{@"x": @(pos[2].x), @"y": @(pos[2].y)};
    NSDictionary *p3 = @{@"x": @(pos[3].x), @"y": @(pos[3].y)};

    res.cornerPoints = @[p0, p1, p2, p3];

    CGFloat minX = MIN(MIN(pos[0].x, pos[1].x), MIN(pos[2].x, pos[3].x));
    CGFloat maxX = MAX(MAX(pos[0].x, pos[1].x), MAX(pos[2].x, pos[3].x));
    CGFloat minY = MIN(MIN(pos[0].y, pos[1].y), MIN(pos[2].y, pos[3].y));
    CGFloat maxY = MAX(MAX(pos[0].y, pos[1].y), MAX(pos[2].y, pos[3].y));

    res.bounds = CGRectMake(minX, minY, maxX - minX, maxY - minY);

    [results addObject:res];
  }

  return results;
}

@end
