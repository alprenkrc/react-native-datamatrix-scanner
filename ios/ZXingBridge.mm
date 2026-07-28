// ZXingBridge.mm
// react-native-datamatrix-scanner

#import "ZXingBridge.h"
#include "ReadBarcode.h"
#include "ReaderOptions.h"
#include "Barcode.h"
#include "ImageView.h"

@implementation ZXingBarcodeResult
@end

@implementation ZXingBridge

+ (NSArray<ZXingBarcodeResult *> *)readDataMatrixFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
  if (!pixelBuffer) return @[];

  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
  void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);

  OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);

  ZXing::ImageFormat format = ZXing::ImageFormat::Lum;

  if (pixelFormat == kCVPixelFormatType_32BGRA) {
    format = ZXing::ImageFormat::BGRX;
  } else if (pixelFormat == kCVPixelFormatType_32ARGB) {
    format = ZXing::ImageFormat::ARGB;
  } else if (pixelFormat == kCVPixelFormatType_32RGBA) {
    format = ZXing::ImageFormat::RGBA;
  } else if (CVPixelBufferIsPlanar(pixelBuffer)) {
    baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    format = ZXing::ImageFormat::Lum;
  }

  if (!baseAddress) {
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return @[];
  }

  ZXing::ImageView imageView(
    static_cast<const uint8_t *>(baseAddress),
    static_cast<int>(width),
    static_cast<int>(height),
    format,
    static_cast<int>(bytesPerRow)
  );

  ZXing::ReaderOptions options;
  options.setFormats(ZXing::BarcodeFormat::DataMatrix);
  options.setTryHarder(true);
  options.setTryRotate(true);
  options.setTryInvert(true);
  options.setTryDownscale(true);
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
