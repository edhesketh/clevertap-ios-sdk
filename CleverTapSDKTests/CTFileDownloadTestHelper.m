//
//  CTFileDownloadTestHelper.m
//  CleverTapSDKTests
//
//  Created by Nikola Zagorchev on 22.06.24.
//  Copyright © 2024 CleverTap. All rights reserved.
//

#import "CTFileDownloadTestHelper.h"
#import <OHHTTPStubs/HTTPStubs.h>

@interface CTFileDownloadTestHelper()

@property (nonatomic, strong) id<HTTPStubsDescriptor> HTTPStub;
@property (nonatomic, strong) NSArray<NSString *> *fileURLTypes;

@end

@implementation CTFileDownloadTestHelper

- (instancetype)init {
    self = [super init];
    if (self) {
        self.filesDownloaded = [NSMutableDictionary new];
        self.fileURLTypes = @[@"txt", @"pdf", @"png"];
    }
    return self;
}

- (NSString *)fileURL {
    return @"ct_test_url";
}

- (int)fileDownloadedCount:(NSURL *)url {
    NSString *key = [url absoluteString];
    if (self.filesDownloaded[key]) {
        return [self.filesDownloaded[key] intValue];
    }
    return -1;
}

- (void)addHTTPStub {
    self.HTTPStub = [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:self.fileURL];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        NSString *fileString = [request.URL absoluteString];
        NSString *fileType = [fileString pathExtension];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        NSNumber *count = self.filesDownloaded[fileString];
        if (count) {
            int value = [count intValue];
            count = [NSNumber numberWithInt:value + 1];
            self.filesDownloaded[fileString] = count;
        } else {
            self.filesDownloaded[fileString] = @1;
        }
        
        if ([fileType isEqualToString:@"txt"]) {
            return [HTTPStubsResponse responseWithFileAtPath:[bundle pathForResource:@"sampleTXTStub" ofType:@"txt"]
                                                  statusCode:200
                                                     headers:nil];
        } else if ([fileType isEqualToString:@"pdf"]) {
            return [HTTPStubsResponse responseWithFileAtPath:[bundle pathForResource:@"samplePDFStub" ofType:@"pdf"]
                                                  statusCode:200
                                                     headers:nil];
        } else {
            return [HTTPStubsResponse responseWithFileAtPath:[bundle pathForResource:@"clevertap-logo" ofType:@"png"]
                                                  statusCode:200
                                                     headers:nil];
        }
    }];
}

- (void)removeStub {
    if (self.HTTPStub) {
        [HTTPStubs removeStub:self.HTTPStub];
    }
}

- (NSArray<NSURL *> *)generateFileURLs:(int)count {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        NSString *urlString = [self generateFileURLStringAtIndex:i];
        [arr addObject:[NSURL URLWithString:urlString]];
    }
    return arr;
}

- (NSArray<NSString *> *)generateFileURLStrings:(int)count {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        NSString *urlString = [self generateFileURLStringAtIndex:i];
        [arr addObject:urlString];
    }
    return arr;
}

- (NSString *)generateFileURLStringAtIndex:(int)index {
    int type = index >= 3 ? index % 3 : index;
    return [NSString stringWithFormat:@"https://clevertap.com/%@_%d.%@", self.fileURL, index, self.fileURLTypes[type]];
}

@end
