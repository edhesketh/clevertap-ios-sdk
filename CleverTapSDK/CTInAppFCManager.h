#import <Foundation/Foundation.h>
#import "CTAttachToBatchHeaderDelegate.h"
#import "CTSwitchUserDelegate.h"

@class CleverTap;
@class CleverTapInstanceConfig;
@class CTInAppNotification;
@class CTInAppEvaluationManager;
@class CTImpressionManager;
@class CTDelegateManager;

@interface CTInAppFCManager : NSObject <CTAttachToBatchHeaderDelegate, CTSwitchUserDelegate>

@property (nonatomic, strong, readonly) CleverTapInstanceConfig *config;
@property (atomic, copy, readonly) NSString *deviceId;
@property (assign, readonly) int localInAppCount;

- (instancetype)initWithConfig:(CleverTapInstanceConfig *)config
                 delegateManager:(CTDelegateManager *)delegateManager
                      deviceId:(NSString *)deviceId
             impressionManager:(CTImpressionManager *)impressionManager;

- (NSString *)storageKeyWithSuffix: (NSString *)suffix;
- (void)checkUpdateDailyLimits;
- (BOOL)canShow:(CTInAppNotification *)inapp;
- (void)didShow:(CTInAppNotification *)inapp;
- (void)updateGlobalLimitsPerDay:(int)perDay andPerSession:(int)perSession;
- (void)removeStaleInAppCounts:(NSArray *)staleInApps;
- (BOOL)hasLifetimeCapacityMaxedOut:(CTInAppNotification *)dictionary;
- (BOOL)hasDailyCapacityMaxedOut:(CTInAppNotification *)dictionary;
- (int)getLocalInAppCount;
- (void)incrementLocalInAppCount;
@end
