//
//  CTInAppDisplayManager.m
//  CleverTapSDK
//
//  Created by Nikola Zagorchev on 3.10.23.
//  Copyright © 2023 CleverTap. All rights reserved.
//
#import "CleverTapInternal.h"
#import "CTInAppDisplayManager.h"
#import "CTPreferences.h"
#import "CTConstants.h"
#import "CTInAppNotification.h"
#import "CTInAppDisplayViewController.h"
#import "CleverTapJSInterface.h"
#import "CTInAppFCManager.h"
#import "CTDeviceInfo.h"
#import "CTEventBuilder.h"
#import "CTUtils.h"
#import "CTUIUtils.h"
#import "CleverTapURLDelegate.h"

#if !CLEVERTAP_NO_INAPP_SUPPORT
#import "CleverTapJSInterface.h"
#import "CTInAppHTMLViewController.h"
#import "CTInterstitialViewController.h"
#import "CTHalfInterstitialViewController.h"
#import "CTCoverViewController.h"
#import "CTHeaderViewController.h"
#import "CTFooterViewController.h"
#import "CTAlertViewController.h"
#import "CTCoverImageViewController.h"
#import "CTInterstitialImageViewController.h"
#import "CTHalfInterstitialImageViewController.h"
#import "CleverTap+InAppNotifications.h"
#import "CTLocalInApp.h"
#import "CleverTap+PushPermission.h"
#import "CleverTapJSInterfacePrivate.h"
#endif

static const void *const kNotificationQueueKey = &kNotificationQueueKey;

// static here as we may have multiple instances handling inapps
static CTInAppDisplayViewController *currentDisplayController;
static NSMutableArray<CTInAppDisplayViewController*> *pendingNotificationControllers;

@interface CTInAppDisplayManager() <CTInAppNotificationDisplayDelegate> {
}

@property (nonatomic, strong) CleverTapInstanceConfig *config;
@property (nonatomic, assign) CleverTapInAppRenderingStatus inAppRenderingStatus;

@property (nonatomic, strong) CTDispatchQueueManager *dispatchQueueManager;

@property (nonatomic, strong) CTInAppFCManager *inAppFCManager;
@property (nonatomic, weak) CleverTap* instance;

@end

@implementation CTInAppDisplayManager

- (instancetype _Nonnull)initWithCleverTap:(CleverTap * _Nonnull)instance
                            dispatchQueueManager:(CTDispatchQueueManager * _Nonnull)dispatchQueueManager
                            inAppFCManager:(CTInAppFCManager *)inAppFCManager
                         impressionManager:(CTImpressionManager *)impressionManager {
    if ((self = [super init])) {
        self.dispatchQueueManager = dispatchQueueManager;
        self.instance = instance;
        self.config = instance.config;
        self.inAppFCManager = inAppFCManager;
    }
    return self;
}

- (void)setPushPrimerManager:(CTPushPrimerManager *)pushPrimerManagerObj {
    pushPrimerManager = pushPrimerManagerObj;
}

#pragma mark - CleverTapInAppNotificationDelegate
@synthesize inAppNotificationDelegate = _inAppNotificationDelegate;

- (void)setInAppNotificationDelegate:(id <CleverTapInAppNotificationDelegate>)delegate {
    if ([CTUIUtils runningInsideAppExtension]){
        CleverTapLogDebug(self.config.logLevel, @"%@: setInAppNotificationDelegate is a no-op in an app extension.", self);
        return;
    }
    if (delegate && [delegate conformsToProtocol:@protocol(CleverTapInAppNotificationDelegate)]) {
        _inAppNotificationDelegate = delegate;
    } else {
        CleverTapLogDebug(self.config.logLevel, @"%@: CleverTap InAppNotification Delegate does not conform to the CleverTapInAppNotificationDelegate protocol", self);
    }
}

- (id<CleverTapInAppNotificationDelegate>)inAppNotificationDelegate {
    return _inAppNotificationDelegate;
}

#pragma mark - InApp Notifications Queue

- (void)_addInAppNotificationsToQueue:(NSArray *)inappNotifs {
    @try {
        NSMutableArray *inapps = [[NSMutableArray alloc] initWithArray:[CTPreferences getObjectForKey:[CTPreferences storageKeyWithSuffix:CLTAP_PREFS_INAPP_KEY config: self.config]]];
        for (int i = 0; i < [inappNotifs count]; i++) {
            @try {
                NSMutableDictionary *inappNotif = [[NSMutableDictionary alloc] initWithDictionary:inappNotifs[i]];
                [inapps addObject:inappNotif];
            } @catch (NSException *e) {
                CleverTapLogInternal(self.config.logLevel, @"%@: Malformed InApp notification", self);
            }
        }
        // Commit all the changes
        [CTPreferences putObject:inapps forKey:[CTPreferences storageKeyWithSuffix:CLTAP_PREFS_INAPP_KEY config: self.config]];

        // Fire the first notification, if any
        [self.dispatchQueueManager runOnNotificationQueue:^{
            [self _showNotificationIfAvailable];
        }];
    } @catch (NSException *e) {
        CleverTapLogInternal(self.config.logLevel, @"%@: InApp notification handling error: %@", self, e.debugDescription);
    }
}

- (void)_showInAppNotificationIfAny {
    if ([CTUIUtils runningInsideAppExtension]){
        CleverTapLogDebug(self.config.logLevel, @"%@: showInAppNotificationIfAny is a no-op in an app extension.", self);
        return;
    }
    if (!self.config.analyticsOnly) {
        [self.dispatchQueueManager runOnNotificationQueue:^{
            [self _showNotificationIfAvailable];
        }];
    }
}

- (void)_suspendInAppNotifications {
    if ([[self class] runningInsideAppExtension]) {
        CleverTapLogDebug(self.config.logLevel, @"%@: suspendInAppNotifications is a no-op in an app extension.", self);
        return;
    }
    if (!self.config.analyticsOnly) {
        self.inAppRenderingStatus = CleverTapInAppSuspend;
        CleverTapLogDebug(self.config.logLevel, @"%@: InApp Notifications will be suspended till resumeInAppNotifications() is not called again", self);
    }
}

- (void)_discardInAppNotifications {
    if ([[self class] runningInsideAppExtension]) {
        CleverTapLogDebug(self.config.logLevel, @"%@: discardInAppNotifications is a no-op in an app extension.", self);
        return;
    }
    if (!self.config.analyticsOnly) {
        self.inAppRenderingStatus = CleverTapInAppDiscard;
        CleverTapLogDebug(self.config.logLevel, @"%@: InApp Notifications will be discarded till resumeInAppNotifications() is not called again", self);
    }
}

- (void)_resumeInAppNotifications {
    if ([CTUIUtils runningInsideAppExtension]) {
        CleverTapLogDebug(self.config.logLevel, @"%@: resumeInAppNotifications is a no-op in an app extension.", self);
        return;
    }
    if (!self.config.analyticsOnly) {
        self.inAppRenderingStatus = CleverTapInAppResume;
        CleverTapLogDebug(self.config.logLevel, @"%@: Resuming inApp Notifications", self);
    }
}

- (void)_showNotificationIfAvailable {
    if ([CTUIUtils runningInsideAppExtension]) return;

    if (self.inAppRenderingStatus == CleverTapInAppSuspend) {
        CleverTapLogDebug(self.config.logLevel, @"%@: InApp Notifications are set to be suspended, not showing the InApp Notification", self);
        return;
    }

    @try {
        NSMutableArray *inapps = [[NSMutableArray alloc] initWithArray:[CTPreferences getObjectForKey:[CTPreferences storageKeyWithSuffix:CLTAP_PREFS_INAPP_KEY config: self.config]]];
        if ([inapps count] < 1) {
            return;
        }
        [self prepareNotificationForDisplay:inapps[0]];
        [inapps removeObjectAtIndex:0];
        [CTPreferences putObject:inapps forKey:[CTPreferences storageKeyWithSuffix:CLTAP_PREFS_INAPP_KEY config: self.config]];
    } @catch (NSException *e) {
        CleverTapLogDebug(self.config.logLevel, @"%@: Problem showing InApp: %@", self, e.debugDescription);
    }
}

- (void)prepareNotificationForDisplay:(NSDictionary*)jsonObj {
    if (!self.instance.isAppForeground) {
        CleverTapLogInternal(self.config.logLevel, @"%@: Application is not in the foreground, won't prepare in-app: %@", self, jsonObj);
        return;
    }

    [self.dispatchQueueManager runOnNotificationQueue:^{
        CleverTapLogInternal(self.config.logLevel, @"%@: processing inapp notification: %@", self, jsonObj);
        __block CTInAppNotification *notification = [[CTInAppNotification alloc] initWithJSON:jsonObj];
        if (notification.error) {
            CleverTapLogInternal(self.config.logLevel, @"%@: unable to parse inapp notification: %@ error: %@", self, jsonObj, notification.error);
            return;
        }

        NSTimeInterval now = (int)[[NSDate date] timeIntervalSince1970];
        if (now > notification.timeToLive) {
            CleverTapLogInternal(self.config.logLevel, @"%@: InApp has elapsed its time to live, not showing the InApp: %@ wzrk_ttl: %lu", self, jsonObj, (unsigned long)notification.timeToLive);
            return;
        }

        [notification prepareWithCompletionHandler:^{
            [CTUtils runSyncMainQueue:^{
                [self notificationReady:notification];
            }];
        }];
    }];
}

- (void)notificationReady:(CTInAppNotification*)notification {
    if (![NSThread isMainThread]) {
        [CTUtils runSyncMainQueue:^{
            [self notificationReady: notification];
        }];
        return;
    }
    if (notification.error) {
        CleverTapLogInternal(self.config.logLevel, @"%@: unable to process inapp notification: %@, error: %@ ", self, notification.jsonDescription, notification.error);
        return;
    }

    CleverTapLogInternal(self.config.logLevel, @"%@: InApp prepared for display: %@", self, notification.campaignId);
    [self displayNotification:notification];
}

- (void)displayNotification:(CTInAppNotification*)notification {
#if !CLEVERTAP_NO_INAPP_SUPPORT
    if (![NSThread isMainThread]) {
        [CTUtils runSyncMainQueue:^{
            [self displayNotification:notification];
        }];
        return;
    }

    if (!self.instance.isAppForeground) {
        CleverTapLogInternal(self.config.logLevel, @"%@: Application is not in the foreground, not displaying in-app: %@", self, notification.jsonDescription);
        return;
    }

    if (![self.inAppFCManager canShow:notification]) {
        CleverTapLogInternal(self.config.logLevel, @"%@: InApp %@ has been rejected by FC, not showing", self, notification.campaignId);
        [self _showInAppNotificationIfAny];  // auto try the next one
        return;
    }

    BOOL goFromDelegate = YES;
    if (self.inAppNotificationDelegate && [self.inAppNotificationDelegate respondsToSelector:@selector(shouldShowInAppNotificationWithExtras:)]) {
        goFromDelegate = [self.inAppNotificationDelegate shouldShowInAppNotificationWithExtras:notification.customExtras];
    }

    if (!goFromDelegate) {
        CleverTapLogDebug(self.config.logLevel, @"%@: Application has decided to not show this InApp: %@", self, notification.campaignId ? notification.campaignId : @"<unknown ID>");
        [self _showInAppNotificationIfAny];  // auto try the next one
        return;
    }

    CTInAppDisplayViewController *controller;
    NSString *errorString = nil;
    CleverTapJSInterface *jsInterface = nil;

    switch (notification.inAppType) {
        case CTInAppTypeHTML:
            jsInterface = [[CleverTapJSInterface alloc] initWithConfigForInApps:self.config];
            controller = [[CTInAppHTMLViewController alloc] initWithNotification:notification jsInterface:jsInterface];
            break;
        case CTInAppTypeInterstitial:
            controller = [[CTInterstitialViewController alloc] initWithNotification:notification];
            break;
        case CTInAppTypeHalfInterstitial:
            controller = [[CTHalfInterstitialViewController alloc] initWithNotification:notification];
            break;
        case CTInAppTypeCover:
            controller = [[CTCoverViewController alloc] initWithNotification:notification];
            break;
        case CTInAppTypeHeader:
            controller = [[CTHeaderViewController alloc] initWithNotification:notification];
            break;
        case CTInAppTypeFooter:
            controller = [[CTFooterViewController alloc] initWithNotification:notification];
            break;
        case CTInAppTypeAlert:
            controller = [[CTAlertViewController alloc] initWithNotification:notification];
            break;
        case CTInAppTypeInterstitialImage:
            controller = [[CTInterstitialImageViewController alloc] initWithNotification:notification];
            break;
        case CTInAppTypeHalfInterstitialImage:
            controller = [[CTHalfInterstitialImageViewController alloc] initWithNotification:notification];
            break;
        case CTInAppTypeCoverImage:
            controller = [[CTCoverImageViewController alloc] initWithNotification:notification];
            break;
        default:
            errorString = [NSString stringWithFormat:@"Unhandled notification type: %lu", (unsigned long)notification.inAppType];
            break;
    }
    if (controller) {
        CleverTapLogDebug(self.config.logLevel, @"%@: Will show new InApp: %@", self, notification.campaignId);
        controller.delegate = self;
        [[self class] displayInAppDisplayController:controller];

        // Update local in-app count only if it is from local push primer.
        if (notification.isLocalInApp && !notification.isPushSettingsSoftAlert) {
            [self.inAppFCManager incrementLocalInAppCount];
        }
    }
    if (errorString) {
        CleverTapLogDebug(self.config.logLevel, @"%@: %@", self, errorString);
    }
#endif
}

- (void)notifyNotificationDismissed:(CTInAppNotification *)notification {
    if (self.inAppNotificationDelegate && [self.inAppNotificationDelegate respondsToSelector:@selector(inAppNotificationDismissedWithExtras:andActionExtras:)]) {
        NSDictionary *extras;
        if (notification.actionExtras && [notification.actionExtras isKindOfClass:[NSDictionary class]]) {
            extras = [NSDictionary dictionaryWithDictionary:notification.actionExtras];
        } else {
            extras = [NSDictionary new];
        }
        [self.inAppNotificationDelegate inAppNotificationDismissedWithExtras:notification.customExtras andActionExtras:extras];
    }
}

- (void)clearInApps {
    CleverTapLogInternal(self.config.logLevel, @"%@: Clearing all pending InApp notifications", self);
    [CTPreferences putObject:[[NSArray alloc] init] forKey:[CTPreferences storageKeyWithSuffix:CLTAP_PREFS_INAPP_KEY config: self.config]];
}

#pragma mark - InAppDisplayController static
+ (void)displayInAppDisplayController:(CTInAppDisplayViewController*)controller {
    // if we are currently displaying a notification, cache this notification for later display
    if (currentDisplayController) {
        [pendingNotificationControllers addObject:controller];
        return;
    }
    // no current notification so display
    currentDisplayController = controller;
    [controller show:YES];
}

+ (void)inAppDisplayControllerDidDismiss:(CTInAppDisplayViewController*)controller {
    if (currentDisplayController && currentDisplayController == controller) {
        currentDisplayController = nil;
        [self checkPendingNotifications];
    }
}

// static display handling as we may have more than one instance competing to show an inapp
+ (void)checkPendingNotifications {
    if (pendingNotificationControllers && [pendingNotificationControllers count] > 0) {
        CTInAppDisplayViewController *controller = [pendingNotificationControllers objectAtIndex:0];
        [pendingNotificationControllers removeObjectAtIndex:0];
        [self displayInAppDisplayController:controller];
    }
}

#pragma mark - CTInAppNotificationDisplayDelegate

- (void)notificationDidDismiss:(CTInAppNotification*)notification fromViewController:(CTInAppDisplayViewController*)controller {
    CleverTapLogInternal(self.config.logLevel, @"%@: InApp did dismiss: %@", self, notification.campaignId);
    [self notifyNotificationDismissed:notification];
    [[self class] inAppDisplayControllerDidDismiss:controller];
    [self _showInAppNotificationIfAny];
}

- (void)notificationDidShow:(CTInAppNotification*)notification fromViewController:(CTInAppDisplayViewController*)controller {
    CleverTapLogInternal(self.config.logLevel, @"%@: InApp did show: %@", self, notification.campaignId);
    [self.instance recordInAppNotificationStateEvent:NO forNotification:notification andQueryParameters:nil];
    [self.inAppFCManager didShow:notification];
}

- (void)notifyNotificationButtonTappedWithCustomExtras:(NSDictionary *)customExtras {
    if (self.inAppNotificationDelegate && [self.inAppNotificationDelegate respondsToSelector:@selector(inAppNotificationButtonTappedWithCustomExtras:)]) {
        [self.inAppNotificationDelegate inAppNotificationButtonTappedWithCustomExtras:customExtras];
    }
}

- (void)handleNotificationCTA:(NSURL *)ctaURL buttonCustomExtras:(NSDictionary *)buttonCustomExtras forNotification:(CTInAppNotification*)notification fromViewController:(CTInAppDisplayViewController*)controller withExtras:(NSDictionary*)extras {
    CleverTapLogInternal(self.config.logLevel, @"%@: handle InApp cta: %@ button custom extras: %@ with options:%@", self, ctaURL.absoluteString, buttonCustomExtras, extras);
    [self.instance recordInAppNotificationStateEvent:YES forNotification:notification andQueryParameters:extras];
    if (extras) {
        notification.actionExtras = extras;
    }
    if (buttonCustomExtras && buttonCustomExtras.count > 0) {
        CleverTapLogDebug(self.config.logLevel, @"%@: InApp: button tapped with custom extras: %@", self, buttonCustomExtras);
        [self notifyNotificationButtonTappedWithCustomExtras:buttonCustomExtras];
    }
    else if (ctaURL) {
        
#if !CLEVERTAP_NO_INAPP_SUPPORT
        if (self.instance.urlDelegate && [self.instance.urlDelegate respondsToSelector: @selector(shouldHandleCleverTapURL: forChannel:)] && ![self.instance.urlDelegate shouldHandleCleverTapURL: ctaURL forChannel: CleverTapInAppNotification]) {
            return;
        }
        [CTUtils runSyncMainQueue:^{
            [CTUIUtils openURL:ctaURL forModule:@"InApp"];
        }];
#endif
    }
    [controller hide:true];
}

- (void)handleInAppPushPrimer:(CTInAppNotification *)notification
           fromViewController:(CTInAppDisplayViewController *)controller
       withFallbackToSettings:(BOOL)isFallbackToSettings {
    CleverTapLogDebug(self.config.logLevel, @"%@: InApp Push Primer Accepted:", self);
    [pushPrimerManager promptForOSPushNotificationWithFallbackToSettings:isFallbackToSettings
                                       andSkipSettingsAlert:notification.skipSettingsAlert];
    
}

- (void)inAppPushPrimerDidDismissed {
    [pushPrimerManager notifyPushPermissionResponse:NO];
}

#pragma mark - Handle InApp test from Push
- (BOOL)didHandleInAppTestFromPushNotificaton:(NSDictionary * _Nullable)notification {
#if !CLEVERTAP_NO_INAPP_SUPPORT
    if ([CTUIUtils runningInsideAppExtension]) {
        return NO;
    }
    
    if (!notification || [notification count] <= 0 || !notification[@"wzrk_inapp"]) return NO;
    
    @try {
        [self.instance.impressionManager resetSession];
        CleverTapLogDebug(self.config.logLevel, @"%@: Received in-app notification from push payload: %@", self, notification);
        
        NSString *jsonString = notification[@"wzrk_inapp"];
        
        NSDictionary *inapp = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                                              options:0
                                                                error:nil];
        
        if (inapp) {
            float delay = self.instance.isAppForeground ? 0.5 : 2.0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    [self prepareNotificationForDisplay:inapp];
                } @catch (NSException *e) {
                    CleverTapLogDebug(self.config.logLevel, @"%@: Failed to display the inapp notifcation from payload: %@", self, e.debugDescription);
                }
            });
        } else {
            CleverTapLogDebug(self.config.logLevel, @"%@: Failed to parse the inapp notification as JSON", self);
            return YES;
        }
        
    } @catch (NSException *e) {
        CleverTapLogDebug(self.config.logLevel, @"%@: Failed to display the inapp notifcation from payload: %@", self, e.debugDescription);
        return YES;
    }
    
#endif
    return YES;
}
@end

