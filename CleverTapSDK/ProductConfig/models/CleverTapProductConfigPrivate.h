#import <Foundation/Foundation.h>
#import "CleverTap+ProductConfig.h"

@protocol CleverTapPrivateProductConfigDelegate <NSObject>
@required

@property (atomic, weak) id<CleverTapProductConfigDelegate> _Nullable productConfigDelegate;

- (void)fetchProductConfig;  // TODO

- (void)setDefaultsProductConfig:(NSDictionary<NSString *, NSObject *> *_Nullable)defaults;

- (void)setDefaultsFromPlistFileNameProductConfig:(NSString *_Nullable)fileName;

- (CleverTapConfigValue *_Nullable)getProductConfig:(NSString* _Nonnull)key;

@end

@interface CleverTapConfigValue() {}

- (instancetype _Nullable )initWithData:(NSDictionary *_Nullable)data;

@end

@interface CleverTapProductConfig () {}

@property(nonatomic, assign) NSTimeInterval minConfigRate;
@property(nonatomic, assign) NSTimeInterval minConfigInterval;

@property (nonatomic, weak) id<CleverTapPrivateProductConfigDelegate> _Nullable privateDelegate;

- (instancetype _Nullable)init __unavailable;

- (instancetype _Nonnull)initWithPrivateDelegate:(id<CleverTapPrivateProductConfigDelegate> _Nonnull)delegate;

- (void)updateProductConfigWithOptions:(NSDictionary *_Nullable)options;

@end