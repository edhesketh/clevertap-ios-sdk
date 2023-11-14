//
//  CTInAppTriggerManager.m
//  CleverTapSDK
//
//  Created by Nikola Zagorchev on 12.09.23.
//  Copyright © 2023 CleverTap. All rights reserved.
//

#import "CTInAppTriggerManager.h"
#import "CTPreferences.h"

@interface CTInAppTriggerManager()

@property (nonatomic, strong) NSString *accountId;
@property (nonatomic, strong) NSString *deviceId;

@end

@implementation CTInAppTriggerManager

- (instancetype)initWithAccountId:(NSString *)accountId
                         deviceId:(NSString *)deviceId {
    self = [super init];
    if (self) {
        self.accountId = accountId;
        self.deviceId = deviceId;
    }
    
    return self;
}


- (NSUInteger)getTriggers:(NSString *)campaignId {
    NSUInteger savedTriggers = [CTPreferences getIntForKey:[self getTriggersKey:campaignId] withResetValue:0];
    
    return savedTriggers;
}

- (void)incrementTrigger:(NSString *)campaignId {
    NSUInteger savedTriggers = [self getTriggers:campaignId];
    savedTriggers++;
    [CTPreferences putInt:savedTriggers forKey:[self getTriggersKey:campaignId]];
}

- (void)removeTriggers:(NSString *)campaignId {
    [CTPreferences removeObjectForKey:[self getTriggersKey:campaignId]];
}

- (NSString *)getTriggersKey:(NSString *)campaignId {
    return [NSString stringWithFormat:@"%@:%@_%@_%@", self.accountId, self.deviceId, @"triggers", campaignId];
}

@end
