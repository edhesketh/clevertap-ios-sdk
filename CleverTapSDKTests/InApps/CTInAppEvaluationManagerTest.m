//
//  CTInAppEvaluationManager.m
//  CleverTapSDKTests
//
//  Created by Nikola Zagorchev on 18.09.23.
//  Copyright © 2023 CleverTap. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "CTInAppEvaluationManager.h"
#import "CTEventAdapter.h"
#import "BaseTestCase.h"
#import "CleverTap+Tests.h"
#import "CleverTapInternal.h"
#import "CTInAppTriggerManager.h"
#import "CTMultiDelegateManager.h"
#import "InAppHelper.h"
#import "CTConstants.h"

@interface CTInAppStore(Tests)
@property (nonatomic, strong) NSArray *serverSideInApps;
@property (nonatomic, strong) NSArray *clientSideInApps;
@end

@interface CTInAppEvaluationManager(Test)
@property (nonatomic, strong) CTInAppTriggerManager *triggerManager;
@property (nonatomic, strong) CTInAppDisplayManager *inAppDisplayManager;
@property (nonatomic, strong) NSMutableArray *suppressedClientSideInApps;
@property (nonatomic, strong) NSMutableArray *evaluatedServerSideInAppIds;
- (void)sortByPriority:(NSMutableArray *)inApps;
- (NSMutableArray *)evaluate:(CTEventAdapter *)event withInApps:(NSArray *)inApps;
- (BOOL)shouldSuppress:(NSDictionary *)inApp;
- (void)suppress:(NSDictionary *)inApp;
- (NSString *)generateWzrkId:(NSString *)ti;
- (void)updateTTL:(NSMutableDictionary *)inApp;
- (void)onAppLaunchedWithSuccess:(BOOL)success;
@end

@interface CTInAppDisplayManagerMock : CTInAppDisplayManager
@property (nonatomic, strong) NSMutableArray *inappNotifs;
- (void)_addInAppNotificationsToQueue:(NSArray *)inappNotifs;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
@implementation CTInAppDisplayManagerMock
- (instancetype)initWithNil {
    if (self = [super initWithCleverTap:nil 
                   dispatchQueueManager:nil
                         inAppFCManager:nil
                      impressionManager:nil
                             inAppStore:nil]) {
        self.inappNotifs = [NSMutableArray new];
    }
    return self;
}
- (void)_addInAppNotificationsToQueue:(NSArray *)inappNotifs {
    [self.inappNotifs addObjectsFromArray:inappNotifs];
}
@end
#pragma clang diagnostic pop

@interface CTInAppEvaluationManagerTest : XCTestCase
@property (nonatomic, strong) CTInAppEvaluationManager *evaluationManager;
@property (nonatomic, strong) InAppHelper *helper;
@property (nonatomic, strong) CTInAppDisplayManagerMock *mockDisplayManager;
@end

@implementation CTInAppEvaluationManagerTest

- (void)setUp {
    [super setUp];
    
    self.helper = [InAppHelper new];
    self.mockDisplayManager = [[CTInAppDisplayManagerMock alloc] initWithNil];
    self.evaluationManager = self.helper.inAppEvaluationManager;
    self.evaluationManager.inAppDisplayManager = self.mockDisplayManager;
}

- (void)tearDown {
    // Clean up resources if needed
    //self.evaluationManager = nil;
    for (int i = 1; i <= 4; i++) {
        [self.evaluationManager.triggerManager removeTriggers:[NSString stringWithFormat:@"%d", i]];
    }
    [super tearDown];
}

- (void)testSort {
    NSMutableArray *inApps = [@[
        @{
            @"ti": @1665140111,
            @"priority": @1
        },
        @{
            @"ti": @1665140999,
            @"priority": @1
        },
        @{
            @"ti": @1665141999,
            @"priority": @100
        },
        @{
            @"ti": @1665140050,
            @"priority": @50
        }] mutableCopy];
    
    NSArray *expectedInApps = @[
        @{
            @"ti": @1665141999,
            @"priority": @100
        },
        @{
            @"ti": @1665140050,
            @"priority": @50
        },
        @{
            @"ti": @1665140111,
            @"priority": @1
        },
        @{
            @"ti": @1665140999,
            @"priority": @1
        }
    ];
    
    [self.evaluationManager sortByPriority:inApps];
    
    XCTAssertEqualObjects(inApps, expectedInApps);
}

- (void)testSortNoPriority {
    NSMutableArray *inApps = [@[
        @{
            @"ti": @1665140111
        },
        @{
            @"ti": @1665140999
        },
        @{
            @"ti": @1665141999,
            @"priority": @2
        }] mutableCopy];
    
    NSArray *expectedInApps = @[
        @{
            @"ti": @1665141999,
            @"priority": @2
        },
        @{
            @"ti": @1665140111
        },
        @{
            @"ti": @1665140999
        }
    ];
    
    [self.evaluationManager sortByPriority:inApps];
    XCTAssertEqualObjects(inApps, expectedInApps);
}

- (void)testSortNoTimestamp {
    NSMutableArray *inApps = [@[
        @{
        },
        @{
            @"priority": @2
        },
        @{
            @"ti": @1665140999
        }] mutableCopy];
    
    NSArray *expectedInApps = @[
        @{
            @"priority": @2
        },
        @{
            @"ti": @1665140999
        },
        @{
        }
    ];
    
    [self.evaluationManager sortByPriority:inApps];
    XCTAssertEqualObjects(inApps, expectedInApps);
}

- (void)testSortInvalidAndStringTimestamp {
    NSMutableArray *inApps = [@[
        @{
            @"priority": @2
        },
        @{
            @"priority": @2,
            @"ti": @"asd"
        },
        @{
            @"priority": @2,
            @"ti": @1699900999
        },
        @{
            @"priority": @2,
            @"ti": @"1699900111"
        }] mutableCopy];
    
    NSArray *expectedInApps = @[
        @{
            @"priority": @2,
            @"ti": @"1699900111"
        },
        @{
            @"priority": @2,
            @"ti": @1699900999
        },
        @{
            @"priority": @2,
        },
        @{
            @"priority": @2,
            @"ti": @"asd"
        }
    ];
    
    [self.evaluationManager sortByPriority:inApps];
    XCTAssertEqualObjects(inApps, expectedInApps);
}

- (void)testEvaluateWithInApps {
    NSArray *inApps = @[
        @{
            @"ti": @1,
            @"priority": @(100),
            @"whenTriggers": @[@{
                @"eventName": @"event1",
                @"eventProperties": @[
                    @{
                        @"propertyName": @"key",
                        @"operator": @1,
                        @"value": @"value"
                    }]
            }],
            @"frequencyLimits": @[
                @{
                    
                }
            ],
            @"occurrenceLimits": @[
                @{
                    
                }
            ]
        },
        @{
            @"ti": @2,
            @"priority": @(100),
            @"whenTriggers": @[@{
                @"eventName": @"event1",
                @"eventProperties": @[
                    @{
                        @"propertyName": @"key",
                        @"operator": @1,
                        @"value": @"value"
                    }]
            }]
        },
        @{
            @"ti": @3,
            @"priority": @(100),
            @"whenTriggers": @[@{
                @"eventName": @"event2"
            }]
        },
        @{
            @"ti": @4,
            @"priority": @(100),
            @"whenTriggers": @[@{
                @"eventName": @"Charged"
            }]
        }
    ];
    
    CTEventAdapter *event = [[CTEventAdapter alloc] initWithEventName:@"event1" eventProperties:@{ @"key": @"value" } andLocation:kCLLocationCoordinate2DInvalid];
    CTEventAdapter *event2 = [[CTEventAdapter alloc] initWithEventName:@"event2" eventProperties:@{} andLocation:kCLLocationCoordinate2DInvalid];
    
    XCTAssertEqualObjects([self.evaluationManager evaluate:event withInApps:inApps], (@[inApps[0], inApps[1]]));
    XCTAssertEqualObjects([self.evaluationManager evaluate:event2 withInApps:inApps], @[inApps[2]]);
    XCTAssertEqualObjects([self.evaluationManager evaluate:event withInApps:inApps], (@[inApps[0], inApps[1]]));
    
    XCTAssertEqual([self.evaluationManager.triggerManager getTriggers:@"1"], 2);
    XCTAssertEqual([self.evaluationManager.triggerManager getTriggers:@"2"], 2);
    XCTAssertEqual([self.evaluationManager.triggerManager getTriggers:@"3"], 1);
    
    // Charged
    CTEventAdapter *eventCharged = [[CTEventAdapter alloc] initWithEventName:CLTAP_CHARGED_EVENT eventProperties:@{} location:kCLLocationCoordinate2DInvalid andItems:@[]];
    
    XCTAssertEqualObjects([self.evaluationManager evaluate:eventCharged withInApps:inApps], @[inApps[3]]);
    XCTAssertEqual([self.evaluationManager.triggerManager getTriggers:@"4"], 1);
}

- (void)testEvaluateCharged {
    self.helper.inAppStore.serverSideInApps = @[
    @{
        @"ti": @1,
        @"whenTriggers": @[@{
            @"eventName": @"event1"
        }]
    },
    @{
        @"ti": @2,
        @"whenTriggers": @[@{
            @"eventName": @"Charged"
        }]
    }];
    [self.evaluationManager evaluateOnChargedEvent:@{} andItems:@[]];
    XCTAssertEqualObjects((@[@2]), self.evaluationManager.evaluatedServerSideInAppIds);
}

- (void)testEvaluateServerSide {
    self.helper.inAppStore.serverSideInApps = @[
    @{
        @"ti": @1,
        @"whenTriggers": @[@{
            @"eventName": @"event1"
        }]
    },
    @{
        @"ti": @2,
        @"whenTriggers": @[@{
            @"eventName": @"event1"
        }]
    },
    @{
        @"ti": @3,
        @"whenTriggers": @[@{
            @"eventName": @"event2"
        }]
    }];
    [self.evaluationManager evaluateOnEvent:@"event1" withProps:@{}];
    XCTAssertEqualObjects((@[@1, @2]), self.evaluationManager.evaluatedServerSideInAppIds);
    [self.evaluationManager evaluateOnEvent:@"event2" withProps:@{}];
    XCTAssertEqualObjects((@[@1, @2, @3]), self.evaluationManager.evaluatedServerSideInAppIds);
}

- (void)testEvaluateClientSide {
    NSArray *inApps = @[
        @{
            @"ti": @1,
            @"whenTriggers": @[@{
                @"eventName": @"event1"
            }]
        },
        @{
            @"ti": @2,
            @"whenTriggers": @[@{
                @"eventName": @"event1"
            }]
        },
        @{
            @"ti": @3,
            @"whenTriggers": @[@{
                @"eventName": @"event2"
            }]
        }];
    self.helper.inAppStore.clientSideInApps = inApps;
    
    [self.evaluationManager evaluateOnEvent:@"event1" withProps:@{}];
    // Add only one based on priority
    XCTAssertEqualObjects((@[inApps[0]]), self.mockDisplayManager.inappNotifs);
    [self.evaluationManager evaluateOnEvent:@"event2" withProps:@{}];
    XCTAssertEqualObjects((@[inApps[0], inApps[2]]), self.mockDisplayManager.inappNotifs);
}

- (void)testEvaluateClientSideSuppressed {
    NSArray *inApps = @[
        @{
            @"ti": @1,
            @"suppressed": @YES,
            @"whenTriggers": @[@{
                @"eventName": @"event1"
            }]
        },
        @{
            @"ti": @2,
            @"suppressed": @YES,
            @"whenTriggers": @[@{
                @"eventName": @"event1"
            }]
        },
        @{
            @"ti": @3,
            @"whenTriggers": @[@{
                @"eventName": @"event1"
            }]
        }];
    self.helper.inAppStore.clientSideInApps = inApps;
    
    [self.evaluationManager evaluateOnEvent:@"event1" withProps:@{}];
    // Suppress all until an in-app can be displayed
    XCTAssertEqualObjects((@[inApps[2]]), self.mockDisplayManager.inappNotifs);
    XCTAssertEqual(2, [self.evaluationManager.suppressedClientSideInApps count]);
}

- (void)testEvaluateOnAppLaunchedWithSuccess {
    NSArray *inApps = @[
        @{
            @"ti": @1,
            @"whenTriggers": @[@{
                @"eventName": @"App Launched"
            }]
        }];
    self.helper.inAppStore.clientSideInApps = inApps;
    
    [self.evaluationManager onAppLaunchedWithSuccess:YES];
    XCTAssertEqualObjects((@[inApps[0]]), self.mockDisplayManager.inappNotifs);
}

- (void)testEvaluateOnAppLaunchedWithFailure {
    NSArray *inApps = @[
        @{
            @"ti": @1,
            @"whenTriggers": @[@{
                @"eventName": @"App Launched"
            }]
        }];
    self.helper.inAppStore.clientSideInApps = inApps;
    // In-app is added on failure
    [self.evaluationManager onAppLaunchedWithSuccess:NO];
    XCTAssertEqualObjects((@[inApps[0]]), self.mockDisplayManager.inappNotifs);
    
    // No in-app is added on retry
    [self.evaluationManager onAppLaunchedWithSuccess:NO];
    XCTAssertEqualObjects((@[inApps[0]]), self.mockDisplayManager.inappNotifs);
    
    // No in-app is added on retry
    [self.evaluationManager onAppLaunchedWithSuccess:YES];
    XCTAssertEqualObjects((@[inApps[0]]), self.mockDisplayManager.inappNotifs);
    
    // Reset notifs
    self.mockDisplayManager.inappNotifs = [NSMutableArray new];
    
    // In-app is added again on success
    [self.evaluationManager onAppLaunchedWithSuccess:YES];
    XCTAssertEqualObjects((@[inApps[0]]), self.mockDisplayManager.inappNotifs);
    
    // Reset notifs
    self.mockDisplayManager.inappNotifs = [NSMutableArray new];
    
    // In-app is added again on failure
    [self.evaluationManager onAppLaunchedWithSuccess:NO];
    XCTAssertEqualObjects((@[inApps[0]]), self.mockDisplayManager.inappNotifs);
}

- (void)testEvaluateOnAppLaunchedClientSide {
    NSArray *inApps = @[
        @{
            @"ti": @1,
            @"whenTriggers": @[@{
                @"eventName": @"App Launched"
            }]
        },
        @{
            @"ti": @2,
            @"whenTriggers": @[@{
                @"eventName": @"App Launched"
            }]
        }];
    self.helper.inAppStore.clientSideInApps = inApps;
    
    [self.evaluationManager evaluateOnAppLaunchedClientSide];
    // Add only one based on priority
    XCTAssertEqualObjects((@[inApps[0]]), self.mockDisplayManager.inappNotifs);
}

- (void)testEvaluateOnAppLaunchedServerSide {
    NSArray *inApps = @[
        @{
            @"ti": @1,
            @"suppressed": @YES,
            @"whenTriggers": @[@{
                @"eventName": @"App Launched"
            }]
        },
        @{
            @"ti": @2,
            @"suppressed": @YES,
            @"whenTriggers": @[@{
                @"eventName": @"App Launched"
            }]
        },
        @{
            @"ti": @3,
            @"whenTriggers": @[@{
                @"eventName": @"App Launched"
            }]
        }];
    
    [self.evaluationManager evaluateOnAppLaunchedServerSide:inApps];
    // Suppress all until an in-app can be displayed
    XCTAssertEqualObjects((@[inApps[2]]), self.mockDisplayManager.inappNotifs);
    XCTAssertEqual(2, [self.evaluationManager.suppressedClientSideInApps count]);
}

- (void)testOnBatchHeaderCreation {
    self.evaluationManager.evaluatedServerSideInAppIds = [@[@1, @2, @3] mutableCopy];
    self.evaluationManager.suppressedClientSideInApps = [@[@4, @5, @6] mutableCopy];
    NSMutableDictionary *expected = [NSMutableDictionary new];
    expected[CLTAP_INAPP_SS_EVAL_META_KEY] = @[@1, @2, @3];
    expected[CLTAP_INAPP_SUPPRESSED_META_KEY] = @[@4, @5, @6];
    
    NSDictionary *batchHeaderKVO = [self.evaluationManager onBatchHeaderCreationForQueue:CTQueueTypeEvents];
    XCTAssertEqualObjects(expected, batchHeaderKVO);
    
    NSDictionary *batchHeaderKVOProfile = [self.evaluationManager onBatchHeaderCreationForQueue:CTQueueTypeProfile];
    XCTAssertEqualObjects(@{}, batchHeaderKVOProfile);
}

- (void)testOnBatchSentRemoveAll {
    self.evaluationManager.evaluatedServerSideInAppIds = [@[@1, @2, @3] mutableCopy];
    self.evaluationManager.suppressedClientSideInApps = [@[@4, @5, @6] mutableCopy];
    NSArray *batchWithHeaderAll = @[
        @{
            CLTAP_INAPP_SS_EVAL_META_KEY: @[@1, @2, @3],
            CLTAP_INAPP_SUPPRESSED_META_KEY: @[@4, @5, @6]
        }
    ];
    [self.evaluationManager onBatchSent:batchWithHeaderAll withSuccess:NO];
    XCTAssertEqualObjects((@[@1, @2, @3]), self.evaluationManager.evaluatedServerSideInAppIds);
    XCTAssertEqualObjects((@[@4, @5, @6]), self.evaluationManager.suppressedClientSideInApps);

    [self.evaluationManager onBatchSent:batchWithHeaderAll withSuccess:YES];
    XCTAssertEqualObjects((@[]), self.evaluationManager.evaluatedServerSideInAppIds);
    XCTAssertEqualObjects((@[]), self.evaluationManager.suppressedClientSideInApps);
}

- (void)testOnBatchSentRemoveElements {
    self.evaluationManager.evaluatedServerSideInAppIds = [@[@1, @2, @3] mutableCopy];
    self.evaluationManager.suppressedClientSideInApps = [@[@4, @5, @6] mutableCopy];
    NSArray *batchWithHeader = @[
        @{
            CLTAP_INAPP_SS_EVAL_META_KEY: @[@1, @2],
            CLTAP_INAPP_SUPPRESSED_META_KEY: @[@4]
        }
    ];
    NSArray *batchWithHeaderAll = @[
        @{
            CLTAP_INAPP_SS_EVAL_META_KEY: @[@1, @2, @3],
            CLTAP_INAPP_SUPPRESSED_META_KEY: @[@4, @5, @6]
        }
    ];
    // If batch is not successful, do not remove elements
    [self.evaluationManager onBatchSent:batchWithHeader withSuccess:NO];
    XCTAssertEqualObjects((@[@1, @2, @3]), self.evaluationManager.evaluatedServerSideInAppIds);
    XCTAssertEqualObjects((@[@4, @5, @6]), self.evaluationManager.suppressedClientSideInApps);

    // Remove only the first n elements in the batch
    [self.evaluationManager onBatchSent:batchWithHeader withSuccess:YES];
    XCTAssertEqualObjects((@[@3]), self.evaluationManager.evaluatedServerSideInAppIds);
    XCTAssertEqualObjects((@[@5, @6]), self.evaluationManager.suppressedClientSideInApps);
    
    // Remove all elements, ensure no out of range exception
    // Current values are @[@3] and @[@5, @6]
    [self.evaluationManager onBatchSent:batchWithHeaderAll withSuccess:YES];
    XCTAssertEqualObjects((@[]), self.evaluationManager.evaluatedServerSideInAppIds);
    XCTAssertEqualObjects((@[]), self.evaluationManager.suppressedClientSideInApps);
}

- (void)testShouldSuppress {
    NSDictionary *inApp = @{
        @"ti": @"1"
    };
    
    NSDictionary *suppressedInApp = @{
        @"ti": @"1",
        @"suppressed": @YES
    };
    
    NSDictionary *notSuppressedInApp = @{
        @"ti": @"1",
        @"suppressed": @NO
    };
    
    XCTAssertFalse([self.evaluationManager shouldSuppress:inApp]);
    XCTAssertTrue([self.evaluationManager shouldSuppress:suppressedInApp]);
    XCTAssertFalse([self.evaluationManager shouldSuppress:notSuppressedInApp]);
}

- (void)testSuppressInApp {
    NSDictionary *inApp = @{
        @"ti": @"1",
        @"wzrk_pivot": @"pivot",
        @"wzrk_cgId": @0
    };
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:CLTAP_DATE_FORMAT];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    
    NSDictionary *suppressedInAppData = @{
        @"wzrk_id": [NSString stringWithFormat:@"1_%@", date],
        @"wzrk_pivot": @"pivot",
        @"wzrk_cgId": @0
    };
    
    [self.evaluationManager suppress:inApp];
    XCTAssertEqual([self.evaluationManager.suppressedClientSideInApps count], 1);
    XCTAssertEqualObjects(self.evaluationManager.suppressedClientSideInApps[0], suppressedInAppData);
    
    NSDictionary *inAppNoPivotNoCG = @{
        @"ti": @"1"
    };
    
    suppressedInAppData = @{
        @"wzrk_id": [NSString stringWithFormat:@"1_%@", date],
        @"wzrk_pivot": @"wzrk_default"
    };
    
    [self.evaluationManager suppress:inAppNoPivotNoCG];
    XCTAssertEqualObjects(self.evaluationManager.suppressedClientSideInApps[1], suppressedInAppData);
}

- (void)testGenerateWzrkId {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:CLTAP_DATE_FORMAT];
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    XCTAssertEqualObjects([self.evaluationManager generateWzrkId:@"1699900111"], ([NSString stringWithFormat:@"1699900111_%@", date]));
}

- (void)testUpdateTTL {
    NSUInteger offset = 24 * 60 *60;
    NSMutableDictionary *inApp = [@{
        @"ti": @"1",
        @"wzrk_ttl_offset": @(offset),
        @"wzrk_ttl": @1700172618
    } mutableCopy];
    
    NSInteger ttl = [[NSDate date] timeIntervalSince1970] + offset;
    NSMutableDictionary *inAppUpdated = [@{
        @"ti": @"1",
        @"wzrk_ttl_offset": @(offset),
        @"wzrk_ttl": [NSNumber numberWithLong:ttl]
    } mutableCopy];
    
    [self.evaluationManager updateTTL:inApp];
    XCTAssertEqualObjects(inAppUpdated, inApp);
    
    NSMutableDictionary *inAppNoTTL = [@{
        @"ti": @"1",
        @"wzrk_ttl_offset": @(offset)
    } mutableCopy];
    [self.evaluationManager updateTTL:inAppNoTTL];
    XCTAssertEqualObjects(inAppUpdated, inAppNoTTL);
    
    NSMutableDictionary *inAppNoOffset = [@{
        @"ti": @"1",
        @"wzrk_ttl": @1700172618
    } mutableCopy];
    [self.evaluationManager updateTTL:inAppNoOffset];
    XCTAssertEqualObjects(@{ @"ti": @"1" }, inAppNoOffset);
}

@end
