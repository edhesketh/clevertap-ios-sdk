//
//  CTInAppEvaluationManager.m
//  CleverTapSDK
//
//  Created by Nikola Zagorchev on 31.08.23.
//  Copyright © 2023 CleverTap. All rights reserved.
//

#import "CTInAppEvaluationManager.h"
#import "CTConstants.h"
#import "CTEventAdapter.h"
#import "CTInAppStore.h"
#import "CTTriggersMatcher.h"
#import "CTLimitsMatcher.h"
#import "CTInAppTriggerManager.h"
#import "CTInAppDisplayManager.h"
#import "CTInAppNotification.h"
#import "CleverTapInternal.h"

@interface CTInAppEvaluationManager()

- (void)evaluateServerSide:(CTEventAdapter *)event;
- (void)evaluateClientSide:(CTEventAdapter *)event;
- (NSMutableArray *)evaluate:(CTEventAdapter *)event withInApps:(NSArray *)inApps;

@property (nonatomic, strong) NSMutableArray *evaluatedServerSideInAppIds;
@property (nonatomic, strong) NSMutableArray *suppressedClientSideInApps;
@property BOOL hasAppLaunchedFailed;

@property (nonatomic, weak) CleverTap *instance;
@property (nonatomic, weak) CTImpressionManager *impressionManager;
@property (nonatomic, strong) CTTriggersMatcher *triggersMatcher;
@property (nonatomic, strong) CTLimitsMatcher *limitsMatcher;
@property (nonatomic, strong) CTInAppTriggerManager *triggerManager;
@property (nonatomic, strong) CTInAppStore *inAppStore;

@end

@implementation CTInAppEvaluationManager

static void *deviceIdContext = &deviceIdContext;
static void *sessionIdContext = &sessionIdContext;

- (instancetype)initWithCleverTap:(CleverTap *)instance
                       deviceInfo:(CTDeviceInfo *)deviceInfo
                impressionManager:(CTImpressionManager *)impressionManager {
    if (self = [super init]) {
        self.instance = instance;
        self.evaluatedServerSideInAppIds = [NSMutableArray new];
        self.suppressedClientSideInApps = [NSMutableArray new];
        
        self.inAppStore = [[CTInAppStore alloc] initWithConfig:instance.config deviceInfo:deviceInfo];
        self.triggersMatcher = [CTTriggersMatcher new];
        self.limitsMatcher = [CTLimitsMatcher new];
        self.triggerManager = [CTInAppTriggerManager new];
        self.impressionManager = impressionManager;
        
        [self.instance setBatchSentDelegate:self];
        [self.instance addAttachToHeaderDelegate:self];
    }
    return self;
}

- (void)evaluateOnEvent:(NSString *)eventName withProps:(NSDictionary *)properties {
    if (![eventName isEqualToString:CLTAP_APP_LAUNCHED_EVENT]) {
        CTEventAdapter *event = [[CTEventAdapter alloc] initWithEventName:eventName eventProperties:properties];
        [self evaluateServerSide:event];
        [self evaluateClientSide:event];
    }
}

- (void)evaluateOnChargedEvent:(NSDictionary *)chargeDetails andItems:(NSArray *)items {
    CTEventAdapter *event = [[CTEventAdapter alloc] initWithEventName:@"Charged" eventProperties:chargeDetails andItems:items];
    [self evaluateServerSide:event];
    [self evaluateClientSide:event];
}

- (void)evaluateOnAppLaunchedClientSide {
    CTEventAdapter *event = [[CTEventAdapter alloc] initWithEventName:CLTAP_APP_LAUNCHED_EVENT eventProperties:@{}];
    [self evaluateClientSide:event];
}

- (void)evaluateOnAppLaunchedServerSide:(NSArray *)appLaunchedNotifs {
    CTEventAdapter *event = [[CTEventAdapter alloc] initWithEventName:CLTAP_APP_LAUNCHED_EVENT eventProperties:@{}];
    NSMutableArray *eligibleInApps = [self evaluate:event withInApps:appLaunchedNotifs];
    [self sortByPriority:eligibleInApps];
    for (NSDictionary *inApp in eligibleInApps) {
        if (![self shouldSuppress:inApp]) {
            [self.instance.inAppDisplayManager _addInAppNotificationsToQueue:@[inApp]];
            break;
        }
        
        [self suppress:inApp];
    }
}

- (void)evaluateClientSide:(CTEventAdapter *)event {
    NSMutableArray *eligibleInApps = [self evaluate:event withInApps:self.inAppStore.clientSideInApps];
    [self sortByPriority:eligibleInApps];
    
    for (NSDictionary *inApp in eligibleInApps) {
        if (![self shouldSuppress:inApp]) {
            NSMutableDictionary  *mutableInApp = [inApp mutableCopy];
            [self updateTTL:mutableInApp];
            [self.instance.inAppDisplayManager _addInAppNotificationsToQueue:@[mutableInApp]];
            break;
        }
        
        [self suppress:inApp];
    }
}

- (void)evaluateServerSide:(CTEventAdapter *)event {
    NSArray *eligibleInApps = [self evaluate:event withInApps:self.inAppStore.serverSideInApps];
    for (NSDictionary *inApp in eligibleInApps) {
        NSString *campaignId = inApp[@"ti"];
        if (campaignId) {
            [self.evaluatedServerSideInAppIds addObject:campaignId];
        }
    }
}

- (NSMutableArray *)evaluate:(CTEventAdapter *)event withInApps:(NSArray *)inApps {
    NSMutableArray *eligibleInApps = [NSMutableArray new];
    for (NSDictionary *inApp in inApps) {
        NSString *campaignId = inApp[@"ti"];
        // Match trigger
        NSArray *whenTriggers = inApp[@"whenTriggers"];
        BOOL matchesTrigger = [self.triggersMatcher matchEventWhenTriggers:whenTriggers event:event];
        if (!matchesTrigger) continue;
        
        // In-app matches the trigger, increment trigger count
        [self.triggerManager incrementTrigger:campaignId];
        
        // Match limits
        NSArray *whenLimits = inApp[@"whenLimits"];
        BOOL matchesLimits = [self.limitsMatcher matchWhenLimits:whenLimits forCampaignId:campaignId withImpressionManager:self.impressionManager];
        if (matchesLimits) {
            [eligibleInApps addObject:inApp];
        }
    }
    
    return eligibleInApps;
}

- (BOOL)evaluateInAppFrequencyLimits:(CTInAppNotification *)inApp {
    if (inApp.jsonDescription && inApp.jsonDescription[@"frequencyLimits"]) {
        // Match frequency limits
        NSArray *frequencyLimits = inApp.jsonDescription[@"frequencyLimits"];
        BOOL matchesLimits = [self.limitsMatcher matchWhenLimits:frequencyLimits forCampaignId:inApp.Id withImpressionManager:self.impressionManager];
        return matchesLimits;
    }
    return YES;
}

- (void)onBatchSent:(NSArray *)batchWithHeader withSuccess:(BOOL)success {
    if (success) {
        NSDictionary *header = batchWithHeader[0];
        [self removeSentEvaluatedServerSideInAppIds:header];
        [self removeSentSuppressedClientSideInApps:header];
    }
}

- (void)onAppLaunchedWithSuccess:(BOOL)success {
    // Handle multiple failures when request is retried
    if (!self.hasAppLaunchedFailed) {
        [self evaluateOnAppLaunchedClientSide];
    }
    self.hasAppLaunchedFailed = !success;
}

- (void)removeSentEvaluatedServerSideInAppIds:(NSDictionary *)header {
    NSArray *inapps_eval = header[@"inapps_eval"];
    if (inapps_eval) {
        [self.evaluatedServerSideInAppIds removeObjectsInRange:NSMakeRange(0, inapps_eval.count)];
    }
}

- (void)removeSentSuppressedClientSideInApps:(NSDictionary *)header {
    NSArray *suppresed_inapps = header[@"inapps_suppressed"];
    if (suppresed_inapps) {
        [self.suppressedClientSideInApps removeObjectsInRange:NSMakeRange(0, suppresed_inapps.count)];
    }
}

- (BOOL)shouldSuppress:(NSDictionary *)inApp {
    return [inApp[@"suppressed"] boolValue];
}

- (void)suppress:(NSDictionary *)inApp {
    NSString *ti = inApp[@"ti"];
    NSString *wzrk_id = [self generateWzrkId:ti];
    NSString *pivot = inApp[@"wzrk_pivot"] ? inApp[@"wzrk_pivot"] : @"wzrk_default";
    NSNumber *cgId = inApp[@"wzrk_cgId"];

    [self.suppressedClientSideInApps addObject:@{
        @"wzrk_id": wzrk_id,
        @"wzrk_pivot": pivot,
        @"wzrk_cgId": cgId
    }];
}

- (void)sortByPriority:(NSMutableArray *)inApps {
    NSNumber *(^priority)(NSDictionary *) = ^NSNumber *(NSDictionary *inApp) {
        NSNumber *priority = inApp[@"priority"];
        if (priority != nil) {
            return priority;
        }
        return @(1);
    };
    
    NSNumber *(^ti)(NSDictionary *) = ^NSNumber *(NSDictionary *inApp) {
        NSNumber *ti = inApp[@"ti"];
        if (ti != nil) {
            return ti;
        }
        return [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    };
    
    // Sort by priority descending since 100 is highest priority and 1 is lowest
    NSSortDescriptor* sortByPriorityDescriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO comparator:^NSComparisonResult(NSDictionary *inAppA, NSDictionary *inAppB) {
        NSNumber *priorityA = priority(inAppA);
        NSNumber *priorityB = priority(inAppB);
        NSComparisonResult comparison = [priorityA compare:priorityB];
        return  comparison;
    }];
    
    // Sort by the earliest created, ascending order of the timestamps
    NSSortDescriptor* sortByTimestampDescriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:YES comparator:^NSComparisonResult(NSDictionary *inAppA, NSDictionary *inAppB) {
        // If priority is the same, display the earliest created
        return [ti(inAppA) compare:ti(inAppB)];
    }];

    // Sort by priority then by timestamp if priority is same
    [inApps sortUsingDescriptors:@[sortByPriorityDescriptor, sortByTimestampDescriptor]];
}

- (NSString *)generateWzrkId:(NSString *)ti {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMdd"];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    NSString *wzrk_id = [NSString stringWithFormat:@"%@_%@", ti, date];
    return wzrk_id;
}

- (void)updateTTL:(NSMutableDictionary *)inApp {
    NSNumber *offset = inApp[@"wzrk_ttl_offset"];
    if (offset != nil) {
        NSInteger now = [[NSDate date] timeIntervalSince1970];
        NSInteger ttl = now + [offset longValue];
        [inApp setObject:[NSNumber numberWithLong:ttl] forKey:@"wzrk_ttl"];
    } else {
        // Remove TTL, since it cannot be calculated based on the TTL offset
        // The deafult TTL will be set in CTInAppNotification
        [inApp removeObjectForKey:@"wzrk_ttl"];
    }
}

- (nonnull NSDictionary<NSString *,id> *)onBatchHeaderCreation {
    NSMutableDictionary *header = [NSMutableDictionary new];
    if ([self.evaluatedServerSideInAppIds count] > 0) {
        header[@"inapps_eval"] = self.evaluatedServerSideInAppIds;
    }
    if ([self.suppressedClientSideInApps count] > 0) {
        header[@"inapps_suppressed"] = self.suppressedClientSideInApps;
    }
    
    return header;
}

@end
