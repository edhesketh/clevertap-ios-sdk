//
//  CTTriggersMatcherTest.m
//  CleverTapSDKTests
//
//  Created by Nikola Zagorchev on 4.09.23.
//  Copyright © 2023 CleverTap. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "CTTriggersMatcher.h"
#import "CTEventAdapter.h"
#import "CTTriggerEvaluator.h"
#import "CTTriggersMatcher+Tests.h"

@interface CTTriggersMatcherTest : XCTestCase

@end

@implementation CTTriggersMatcherTest

#pragma mark Event
- (void)testMatchEventAllOperators {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @0,
                    @"propertyValue": @150
                },
                @{
                    @"propertyName": @"prop2",
                    @"operator": @1,
                    @"propertyValue": @"Equals"
                },
                @{
                    @"propertyName": @"prop3",
                    @"operator": @2,
                    @"propertyValue": @150
                },
                @{
                    @"propertyName": @"prop4",
                    @"operator": @3,
                    @"propertyValue": @"Contains"
                },
                @{
                    @"propertyName": @"prop5",
                    @"operator": @4,
                    @"propertyValue": @[@1, @3]
                },
                @{
                    @"propertyName": @"prop6",
                    @"operator": @15,
                    @"propertyValue": @"NotEquals"
                },
                @{
                    @"propertyName": @"prop7",
                    @"operator": @26
                },
                @{
                    @"propertyName": @"prop8",
                    @"operator": @27
                },
                @{
                    @"propertyName": @"prop9",
                    @"operator": @28,
                    @"propertyValue": @"NotContains"
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @160,
        @"prop2": @"Equals",
        @"prop3": @140,
        @"prop4": @"Contains CleverTap",
        @"prop5": @2,
        @"prop6": @"NotEquals!",
        @"prop7": @"is set",
        @"prop9": @"No Contains",
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchEventWithoutTriggerProps {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1"
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"clevertap"
    }];
    XCTAssertTrue(match);
    
    BOOL matchNoProps = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{}];
    XCTAssertTrue(matchNoProps);
}

- (void)testMatchEventWithEmptyTriggerProps {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"clevertap"
    }];
    XCTAssertTrue(match);
    
    BOOL matchNoProps = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{}];
    XCTAssertTrue(matchNoProps);
}

- (void)testMatchEventWithoutProps {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @"test"
                }],
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL matchNoProps = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{}];
    XCTAssertFalse(matchNoProps);
}

#pragma mark Charged Event

- (void)testMatchChargedEvent {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"Charged",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                }],
            @"itemProperties": @[
                @{
                    @"propertyName": @"product_name",
                    @"operator": @1,
                    @"propertyValue": @"product 1"
                }]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{
        @"prop1": @150,
    } items:@[
        @{
            @"product_name": @"product 1",
            @"price": @5.99
        },
        @{
            @"product_name": @"product 2",
            @"price": @5.50
        }
    ]];
    
    XCTAssertTrue(match);
}

- (void)testChargedWithoutItems {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"Charged",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                }],
            @"itemProperties": @[]
        }
    ];
    
    NSArray *whenTriggersNoItems = @[
        @{
            @"eventName": @"Charged",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                }]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{
        @"prop1": @150,
    } items:@[
        @{
            @"product_name": @"product 1",
            @"price": @5.99
        },
        @{
            @"product_name": @"product 2",
            @"price": @5.50
        }
    ]];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggersNoItems details:@{
        @"prop1": @150,
    } items:@[
        @{
            @"product_name": @"product 1",
            @"price": @5.99
        },
        @{
            @"product_name": @"product 2",
            @"price": @5.50
        }
    ]];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{
        @"prop1": @150,
    } items:@[]];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggersNoItems details:@{
        @"prop1": @150,
    } items:@[]];
    XCTAssertTrue(match);
}

- (void)testMatchChargedEventItemArrayEquals {
    
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"Charged",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                }],
            @"itemProperties": @[
                @{
                    @"propertyName": @"product_name",
                    @"operator": @1,
                    @"propertyValue": @[@"product 1", @"product 2"]
                }]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{
        @"prop1": @150,
    } items:@[
        @{
            @"product_name": @"product 1",
            @"price": @5.99
        },
        @{
            @"product_name": @"product 2",
            @"price": @5.50
        }
    ]];
    
    XCTAssertTrue(match);
}

- (void)testMatchChargedEventItemArrayContains {
    
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"Charged",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                }],
            @"itemProperties": @[
                @{
                    @"propertyName": @"product_name",
                    @"operator": @3,
                    @"propertyValue": @[@"product 1", @"product 2"]
                }]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{
        @"prop1": @150,
    } items:@[
        @{
            @"product_name": @"product 1",
            @"price": @5.99
        },
        @{
            @"product_name": @"product 2",
            @"price": @5.50
        }
    ]];
    
    XCTAssertTrue(match);
}

#pragma mark Equals

- (void)testMatchEqualsPrimitives {
    
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                },
                @{
                    @"propertyName": @"prop2",
                    @"operator": @1,
                    @"propertyValue": @200
                },
                @{
                    @"propertyName": @"prop3",
                    @"operator": @1,
                    @"propertyValue": @150
                },
                @{
                    @"propertyName": @"prop4",
                    @"operator": @1,
                    @"propertyValue": @"CleverTap"
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150,
        @"prop2": @200,
        @"prop3": @"150",
        @"prop4": @"CleverTap"
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchEqualsNumbers {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                },
                @{
                    @"propertyName": @"prop2",
                    @"operator": @1,
                    @"propertyValue": @"200"
                },
                @{
                    @"propertyName": @"prop3",
                    @"operator": @1,
                    @"propertyValue": @[@150, @"200", @0.55]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150,
        @"prop2": @200,
        @"prop3": @200
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"150",
        @"prop2": @200,
        @"prop3": @"150"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"150.00",
        @"prop2": @200.00,
        @"prop3": @"0.55"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"150.00",
        @"prop2": @200,
        @"prop3": @"0.56"
    }];
    XCTAssertFalse(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150,
        @"prop2": @"200",
        @"prop3": @"55"
    }];
    XCTAssertFalse(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"test",
        @"prop2": @"test",
        @"prop3": @"test"
    }];
    XCTAssertFalse(match);
}

- (void)testMatchEqualsNumbersCharged {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"Charged",
            @"itemProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                },
                @{
                    @"propertyName": @"prop2",
                    @"operator": @1,
                    @"propertyValue": @"200"
                },
                @{
                    @"propertyName": @"prop3",
                    @"operator": @1,
                    @"propertyValue": @[@150, @"200", @0.55]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[@{
        @"prop1": @"150",
        @"prop2": @200,
        @"prop3": @"150"
    }]];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[
        @{
            @"prop1": @1,
            @"prop2": @2,
            @"prop3": @3
        },
        @{
            @"prop1": @150,
            @"prop2": @200,
            @"prop3": @0.55
        },
    ]];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[
        @{
            @"prop1": @1,
            @"prop2": @2,
            @"prop3": @3
        }
    ]];
    XCTAssertFalse(match);
}

- (void)testMatchEqualsDouble {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @(150.95)
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150.950
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"150.950"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"150.96"
    }];
    XCTAssertFalse(match);
}

- (void)testMatchEqualsExtectedStringWithActualArray {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @"test"
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"test", @"test2"]
    }];
    
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"test1", @"test2"]
    }];
    
    XCTAssertFalse(match);
}

- (void)testMatchEqualsExtectedArrayWithActualString {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @[@"test", @"test1"]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"test"]
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"test1"]
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"test2"]
    }];
    XCTAssertFalse(match);
}

- (void)testMatchEqualsExtectedNumberWithActualArray {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"test", @150]
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchEqualsExtectedStringWithActualString {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @"test"
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"test"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"Test"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"TEST"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @12
    }];
    XCTAssertFalse(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": [NSNull null]
    }];
    XCTAssertFalse(match);
}

- (void)testMatchEqualsExtectedNumberWithActualString {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"test"
    }];
    XCTAssertFalse(match);
}

- (void)testMatchEqualsExtectedDoubleWithActualDouble {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150.99
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150.99
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchEqualsExtectedDoubleWithActualDoubleString {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150.99
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"150.99"
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchEqualsExtectedArrayWithActualArray {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @[@"test", @"test2", @"test3"]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"test2", @"test3", @"test"]
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchEqualsExtectedArrayWithActualArrayNumber {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @[@1, @2, @3]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@3, @1, @2]
    }];
    
    XCTAssertTrue(match);
}

#pragma mark Set
- (void)testMatchSet {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @26
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150
    }];
    XCTAssertTrue(match);
}

- (void)testMatchSetCharged {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"Charged",
            @"itemProperties": @[
                @{
                    @"propertyName": @"item1",
                    @"operator": @26
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[
        @{
            @"item2": @1
        },
        @{
            @"item1": @1
        }
    ]];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[
        @{
            @"item2": @1
        }
    ]];
    XCTAssertFalse(match);
}

#pragma mark Not Set
- (void)testMatchNotSet {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @27
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop2": @150
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchNotSetCharged {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"Charged",
            @"itemProperties": @[
                @{
                    @"propertyName": @"item1",
                    @"operator": @27
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[
        @{
            @"item2": @1
        },
        @{
            @"item1": @1
        }
    ]];
    XCTAssertFalse(match);
    
    match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[
        @{
            @"item2": @1
        }
    ]];
    XCTAssertTrue(match);
}

#pragma mark Not Equals
- (void)testMatchNotEquals {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @15,
                    @"propertyValue": @150
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @240
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150
    }];
    XCTAssertFalse(match);
}

- (void)testMatchNotEqualsArrays {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @15,
                    @"propertyValue": @[@150, @240]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@241]
    }];
    XCTAssertTrue(match);
    
    // If any Not Equals any
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@150, @100]
    }];
    XCTAssertTrue(match);
}

#pragma mark Less Than
- (void)testMatchLessThan {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @2,
                    @"propertyValue": @240
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150
    }];
    
    XCTAssertTrue(match);
    
    BOOL matchNoProp = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
    }];
    
    XCTAssertFalse(matchNoProp);
}

- (void)testMatchLessThanWithString {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @2,
                    @"propertyValue": @240
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"-120"
    }];
    
    XCTAssertTrue(match);
    
    BOOL matchNaN = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"asd"
    }];
    
    XCTAssertFalse(matchNaN);
}

- (void)testMatchLessThanWithArrays {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @2,
                    @"propertyValue": @[@240]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"-120"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@250, @-1]
    }];
    XCTAssertTrue(match);
    
    whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @2,
                    @"propertyValue": @[@240, @500]
                }
            ]
        }
    ];
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"-120"
    }];
    XCTAssertFalse(match);
}

#pragma mark Greater Than
- (void)testMatchGreaterThan {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @0,
                    @"propertyValue": @150
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @240
    }];
    
    XCTAssertTrue(match);
    
    BOOL matchNoProp = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
    }];
    
    XCTAssertFalse(matchNoProp);
}

- (void)testMatchGreaterThanWithString {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @0,
                    @"propertyValue": @150
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"240"
    }];
    
    XCTAssertTrue(match);
    
    BOOL matchNaN = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"asd"
    }];
    
    XCTAssertFalse(matchNaN);
}

- (void)testMatchGreaterThanWithArrays {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @0,
                    @"propertyValue": @[@240]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @600
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@250, @-1, @600]
    }];
    XCTAssertTrue(match);
    
    whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @0,
                    @"propertyValue": @[@240, @500]
                }
            ]
        }
    ];
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @600
    }];
    XCTAssertFalse(match);
}

#pragma mark Between
- (void)testMatchBetween {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @4,
                    @"propertyValue": @[@100, @240]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @100
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @240
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"150"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @1
    }];
    XCTAssertFalse(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @250
    }];
    XCTAssertFalse(match);
    
    BOOL matchNan = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"a150"
    }];
    
    XCTAssertFalse(matchNan);
}

- (void)testMatchBetweenCharged {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"Charged",
            @"itemProperties": @[
                @{
                    @"propertyName": @"item1",
                    @"operator": @4,
                    @"propertyValue": @[@100, @240]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[
        @{
            @"item1": @1
        },
        @{
            @"item1": @101
        }
    ]];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchChargedEventWhenTriggers:whenTriggers details:@{} items:@[
        @{
            @"item1": @300
        },
        @{
            @"item1": @400
        }
    ]];
    XCTAssertFalse(match);
}

- (void)testMatchBetweenArrayMoreThan2 {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @4,
                    @"propertyValue": @[@100, @240, @330, @"test"]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchBetweenEmptyArray {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @4,
                    @"propertyValue": @[]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @150
    }];
    
    XCTAssertFalse(match);
}

#pragma mark Contains
- (void)testMatchContainsString {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @3,
                    @"propertyValue": @"clever"
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"clevertap"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"cle"
    }];
    XCTAssertFalse(match);
}

- (void)testMatchContainsArray {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @3,
                    @"propertyValue": @[@"clever", @"test"]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"clevertap"
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchContainsArrayEmpty {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @3,
                    @"propertyValue": @[]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"clevertap"
    }];
    
    XCTAssertFalse(match);
}

- (void)testMatchContainsStringWithPropertyArray {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @3,
                    @"propertyValue": @"clever"
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"clevertap",@"test"]
    }];
    
    XCTAssertTrue(match);
}

#pragma mark Not Contains
- (void)testMatchNotContainsArray {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @28,
                    @"propertyValue": @[@"testing", @"test"]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"clevertap"
    }];
    
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"te"
    }];
    XCTAssertTrue(match);
    
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"test"
    }];
    XCTAssertFalse(match);
}

- (void)testMatchNotContainsArrayFromTriggerArray {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @28,
                    @"propertyValue": @[@"testing", @"test"]
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @[@"clevertap", @"yes"]
    }];
    
    XCTAssertTrue(match);
}

- (void)testMatchNotContainsString {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @28,
                    @"propertyValue": @"test"
                }
            ]
        }
    ];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers eventName:@"event1" eventProperties:@{
        @"prop1": @"clevertap"
    }];
    
    XCTAssertTrue(match);
}

#pragma mark GeoRadius
- (void)testMatchEventWithGeoRadius {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"geoRadius": @[
                @{
                    @"lat": @19.07609,
                    @"lng": @72.877426,
                    @"rad": @2
                }]
        }
    ];
    
    // Distance ~1.1km
    CLLocationCoordinate2D location1km = CLLocationCoordinate2DMake(19.08609, 72.877426);
    
    CTEventAdapter *event = [[CTEventAdapter alloc] initWithEventName:@"event1" eventProperties:@{} andLocation:location1km];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers event:event];
    XCTAssertTrue(match);
    
    // Distance ~2.2km
    CLLocationCoordinate2D location2km = CLLocationCoordinate2DMake(19.09609, 72.877426);
    event = [[CTEventAdapter alloc] initWithEventName:@"event1" eventProperties:@{} andLocation:location2km];
    match = [triggerMatcher matchEventWhenTriggers:whenTriggers event:event];
    XCTAssertFalse(match);
}

- (void)testMatchEventWithGeoRadiusButNotParams {
    NSArray *whenTriggers = @[
        @{
            @"eventName": @"event1",
            @"eventProperties": @[
                @{
                    @"propertyName": @"prop1",
                    @"operator": @1,
                    @"propertyValue": @150
                }],
            @"geoRadius": @[
                @{
                    @"lat": @19.07609,
                    @"lng": @72.877426,
                    @"rad": @2
                }]
        }
    ];
    
    // Distance ~1.1km
    CLLocationCoordinate2D location1km = CLLocationCoordinate2DMake(19.08609, 72.877426);
    
    CTEventAdapter *event = [[CTEventAdapter alloc] initWithEventName:@"event1" eventProperties:@{@"prop1": @151} andLocation:location1km];
    
    CTTriggersMatcher *triggerMatcher = [[CTTriggersMatcher alloc] init];
    
    BOOL match = [triggerMatcher matchEventWhenTriggers:whenTriggers event:event];
    XCTAssertFalse(match);
}

@end
