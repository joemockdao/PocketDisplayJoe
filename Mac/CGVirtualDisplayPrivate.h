// API privata di CoreGraphics per creare display virtuali (dichiarazioni scritte per questo progetto).
// Non esiste un'alternativa pubblica senza una DriverKit extension con entitlement Apple.
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class CGVirtualDisplayDescriptor;

@interface CGVirtualDisplayMode : NSObject
@property (readonly, nonatomic) CGFloat refreshRate;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height refreshRate:(CGFloat)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (retain, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
@property (nonatomic) unsigned int hiDPI;
- (instancetype)init;
@end

@interface CGVirtualDisplay : NSObject
@property (readonly, nonatomic) CGDirectDisplayID displayID;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property (retain, nonatomic, nullable) NSString *name;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int serialNum;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int vendorID;
- (instancetype)init;
- (void)setDispatchQueue:(dispatch_queue_t)queue;
@end

NS_ASSUME_NONNULL_END
