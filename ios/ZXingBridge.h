// ZXingBridge.h
// react-native-datamatrix-scanner

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZXingBarcodeResult : NSObject

@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy, nullable) NSString *raw;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSNumber *> *> *cornerPoints;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, assign) NSInteger imageWidth;
@property (nonatomic, assign) NSInteger imageHeight;

@end

@interface ZXingBridge : NSObject

+ (NSArray<ZXingBarcodeResult *> *)readDataMatrixFromPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
