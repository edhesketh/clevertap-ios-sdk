#import <XCTest/XCTest.h>
#import <OHHTTPStubs/HTTPStubs.h>
#import "CTPreferences.h"
#import "CTConstants.h"
#import "CTFileDownloader.h"
#import "CTFileDownloadManager.h"

NSString *const fileURL = @"ct_test_url";
NSString *const fileTypes[] = {@"txt", @"pdf", @"png"};

@interface CTFileDownloader(Tests)

@property (nonatomic, strong) CTFileDownloadManager *fileDownloadManager;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *urlsExpiry;
@property (nonatomic) NSTimeInterval fileExpiryTime;
- (long)currentTimeInterval;
- (void)removeInactiveExpiredAssets:(long)lastDeletedTime;
- (void)removeDeletedFilesFromExpiry:(NSDictionary<NSString *, id> *)status;
- (void)updateFilesExpiryInPreference;
- (void)updateLastDeletedTimestamp;
- (long)getLastDeletedTimestamp;
- (void)deleteFiles:(NSArray<NSString *> *)urls withCompletionBlock:(CTFilesDeleteCompletedBlock)completion;
- (void)migrateActiveAndInactiveUrls;
- (NSString *)storageKeyWithSuffix:(NSString *)suffix;
- (void)updateFilesExpiry:(NSDictionary<NSString *, NSNumber *> *)status;

@end

@interface CTFileDownloaderMock: CTFileDownloader

@property (nonatomic) long mockCurrentTimeInterval;
@property (nonatomic) void(^removeInactiveExpiredAssetsBlock)(long);

@property (nonatomic) CTFilesDeleteCompletedBlock deleteCompletion;
@property (nonatomic) void(^deleteFilesInvokedBlock)(NSArray<NSString *> *);

@end

@implementation CTFileDownloaderMock

- (long)currentTimeInterval {
    if (self.mockCurrentTimeInterval) {
        return self.mockCurrentTimeInterval;
    }
    return [super currentTimeInterval];
}

- (void)removeInactiveExpiredAssets:(long)lastDeletedTime {
    if (self.removeInactiveExpiredAssetsBlock) {
        self.removeInactiveExpiredAssetsBlock(lastDeletedTime);
    }
    [super removeInactiveExpiredAssets:lastDeletedTime];
}

- (void)deleteFiles:(NSArray<NSString *> *)urls withCompletionBlock:(CTFilesDeleteCompletedBlock)completion {
    if (self.deleteFilesInvokedBlock) {
        self.deleteFilesInvokedBlock(urls);
    }
    CTFilesDeleteCompletedBlock completionBlock = ^(NSDictionary<NSString *,id> *status) {
        if (completion) {
            completion(status);
        }
        if (self.deleteCompletion) {
            self.deleteCompletion(status);
        }
    };
    [super deleteFiles:urls withCompletionBlock:completionBlock];
}

@end

@interface CTFileDownloaderTests : XCTestCase

@property (nonatomic, strong) CleverTapInstanceConfig *config;
@property (nonatomic, strong) CTFileDownloaderMock *fileDownloader;
@property (nonatomic, strong) NSArray *fileURLs;

@end

@implementation CTFileDownloaderTests

- (void)setUp {
    [super setUp];
    [self addAllStubs];
    self.config = [[CleverTapInstanceConfig alloc] initWithAccountId:@"testAccountId" accountToken:@"testAccountToken"];
    self.fileDownloader = [[CTFileDownloaderMock alloc] initWithConfig:self.config];
}

- (void)tearDown {
    [super tearDown];
    
    [HTTPStubs removeAllStubs];
    [CTPreferences removeObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_URLS_EXPIRY_DICT]];
    [CTPreferences removeObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_ASSETS_LAST_DELETED_TS]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for cleanup"];
    self.fileDownloader.deleteCompletion = ^(NSDictionary<NSString *,id> * _Nonnull status) {
        [expectation fulfill];
    };
    
    [self.fileDownloader clearFileAssets:NO];
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (void)testMigration {
    NSArray<NSString *> *activeAssetsArray = @[@"url0", @"url1"];
    NSArray<NSString *> *inactiveAssetsArray = @[@"url2", @"url3"];
    [CTPreferences putObject:activeAssetsArray forKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_PREFS_CS_INAPP_ACTIVE_ASSETS]];
    [CTPreferences putObject:inactiveAssetsArray forKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_PREFS_CS_INAPP_INACTIVE_ASSETS]];
    
    long ts = (long)[[NSDate date] timeIntervalSince1970];
    self.fileDownloader.mockCurrentTimeInterval = ts;
    [CTPreferences putInt:ts forKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_PREFS_CS_INAPP_ASSETS_LAST_DELETED_TS]];
    
    [self.fileDownloader migrateActiveAndInactiveUrls];
    
    XCTAssertNil([CTPreferences getObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_PREFS_CS_INAPP_ACTIVE_ASSETS]]);
    XCTAssertNil([CTPreferences getObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_PREFS_CS_INAPP_INACTIVE_ASSETS]]);
    NSDictionary *urlsExpiry = [CTPreferences getObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_URLS_EXPIRY_DICT]];
    NSDictionary *urlsExpiryExpected = @{
        @"url0": @(ts + self.fileDownloader.fileExpiryTime),
        @"url1": @(ts + self.fileDownloader.fileExpiryTime),
        @"url2": @(ts + self.fileDownloader.fileExpiryTime),
        @"url3": @(ts + self.fileDownloader.fileExpiryTime)
    };
    XCTAssertTrue([urlsExpiryExpected isEqualToDictionary:urlsExpiry]);
    
    XCTAssertNil([CTPreferences getObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_PREFS_CS_INAPP_ASSETS_LAST_DELETED_TS]]);
    id filesLastDeletedTs = [CTPreferences getObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_ASSETS_LAST_DELETED_TS]];
    XCTAssertEqual(ts, [filesLastDeletedTs longValue]);
}

- (void)testSetup {
    NSDictionary *urlsExpiry= @{
        @"url0": @(1),
        @"url1": @(1)
    };
    [CTPreferences putObject:urlsExpiry forKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_URLS_EXPIRY_DICT]];
    
    self.fileDownloader = [[CTFileDownloaderMock alloc] initWithConfig:self.config];
    XCTAssertTrue([urlsExpiry isEqualToDictionary:self.fileDownloader.urlsExpiry]);
    
    [CTPreferences removeObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_URLS_EXPIRY_DICT]];
    self.fileDownloader = [[CTFileDownloaderMock alloc] initWithConfig:self.config];
    XCTAssertNotNil(self.fileDownloader.urlsExpiry);
    XCTAssertEqual(0, self.fileDownloader.urlsExpiry.count);
}

- (void)testDefaultExpiryTime {
    XCTAssertEqual(self.fileDownloader.fileExpiryTime, CLTAP_FILE_EXPIRY_OFFSET);
}

- (void)testFileAlreadyPresent {
    NSArray *urls = [self generateFileURLs:2];
    XCTAssertFalse([self.fileDownloader isFileAlreadyPresent:urls[0]]);
    XCTAssertFalse([self.fileDownloader isFileAlreadyPresent:urls[1]]);
    
    [self downloadFiles:@[urls[0]]];
    
    XCTAssertTrue([self.fileDownloader isFileAlreadyPresent:urls[0]]);
    XCTAssertFalse([self.fileDownloader isFileAlreadyPresent:urls[1]]);
}

- (void)testImageLoadedFromDisk {
    // Download files
    NSArray *urls = [self generateFileURLs:3];
    // Download files, urls[2] is of type txt
    [self downloadFiles:@[urls[2]]];
    
    // Check image is present in disk cache
    UIImage *image = [self.fileDownloader loadImageFromDisk:urls[2]];
    XCTAssertNotNil(image);
}

- (void)testImageNotLoadedFromDisk {
    NSArray *urls = [self generateFileURLs:3];
    // Download files, urls[0] is of type txt
    [self downloadFiles:@[urls[0]]];
    
    // Check image is present in disk cache
    UIImage *image = [self.fileDownloader loadImageFromDisk:urls[0]];
    XCTAssertNil(image);
}

- (void)testFileDownloadPath {
    NSArray *urls = [self generateFileURLs:1];
    [self downloadFiles:urls];
    NSString *filePath = [self.fileDownloader getFileDownloadPath:urls[0]];

    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *expectedFilePath = [documentsPath stringByAppendingPathComponent:[urls[0] lastPathComponent]];
    XCTAssertNotNil(filePath);
    XCTAssertEqualObjects(filePath, expectedFilePath);
}

- (void)testFileDownloadPathNotFound {
    NSArray *urls = [self generateFileURLs:1];
    NSString *filePath = [self.fileDownloader getFileDownloadPath:urls[0]];
    XCTAssertNil(filePath);
}

- (void)testDownloadEmptyUrls {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Download files"];
    [self.fileDownloader downloadFiles:@[] withCompletionBlock:^(NSDictionary<NSString *,id> * _Nullable status) {
        XCTAssertNotNil(status);
        XCTAssertTrue(status.count == 0);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (void)testDownloadUpdatesFileExpiryTs {
    // Mock currentTimeInterval
    long ts = (long)[[NSDate date] timeIntervalSince1970];
    self.fileDownloader.mockCurrentTimeInterval = ts;
    
    NSString *url = [self generateFileURLs:1][0];
    XCTAssertNil(self.fileDownloader.urlsExpiry[url]);
    
    [self downloadFiles:@[url]];
    long expiryDate = ts + self.fileDownloader.fileExpiryTime;
    XCTAssertEqualObjects(@(expiryDate), self.fileDownloader.urlsExpiry[url]);
    
    self.fileDownloader.mockCurrentTimeInterval = ts + 100;
    [self downloadFiles:@[url]];
    XCTAssertEqualObjects(@(expiryDate + 100), self.fileDownloader.urlsExpiry[url]);
}

- (void)testDownloadUpdatesFileExpiryCache {
    NSArray *urls = [self generateFileURLs:2];
    XCTAssertEqual(0, self.fileDownloader.urlsExpiry.count);
    
    long ts = (long)[[NSDate date] timeIntervalSince1970];
    self.fileDownloader.mockCurrentTimeInterval = ts;
    [self downloadFiles:urls];
    NSDictionary *urlsExpiry = [NSDictionary dictionaryWithDictionary:self.fileDownloader.urlsExpiry];
    XCTAssertEqual(2, self.fileDownloader.urlsExpiry.count);
    XCTAssertEqualObjects(self.fileDownloader.urlsExpiry, [CTPreferences getObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_URLS_EXPIRY_DICT]]);
    
    self.fileDownloader.mockCurrentTimeInterval = ts + 100;
    [self downloadFiles:urls];
    XCTAssertNotEqualObjects(urlsExpiry, self.fileDownloader.urlsExpiry);
    XCTAssertEqualObjects(self.fileDownloader.urlsExpiry, [CTPreferences getObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_URLS_EXPIRY_DICT]]);
}

- (void)testDownloadTriggersRemoveExpired {
    NSArray *urls = [self generateFileURLs:2];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Download triggers remove expired files."];
    long lastDeletedTs = [self.fileDownloader getLastDeletedTimestamp];
    self.fileDownloader.removeInactiveExpiredAssetsBlock = ^(long lastDeleted) {
        XCTAssertEqual(lastDeletedTs, lastDeleted);
        [expectation fulfill];
    };
    [self downloadFiles:urls];
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (void)testRemoveExpiredAssetsNotCalledLastDeleted {
    // This block is synchronous
    self.fileDownloader.deleteFilesInvokedBlock = ^(NSArray<NSString *> *urls) {
        XCTFail();
    };
    
    long ts = (long)[[NSDate date] timeIntervalSince1970];
    long lastDeleted = ts - 1;
    self.fileDownloader.mockCurrentTimeInterval = ts;
    self.fileDownloader.urlsExpiry = [@{
        @"url0": @(4)
    } mutableCopy];
    [self.fileDownloader removeInactiveExpiredAssets:lastDeleted];
    self.fileDownloader.deleteFilesInvokedBlock = nil;
}

- (void)testRemoveExpiredAssets {
    long ts = (long)[[NSDate date] timeIntervalSince1970];
    
    NSString *expiredUrl1 = @"url0-expired";
    NSString *expiredUrl2 = @"url2-expired";

    self.fileDownloader.deleteFilesInvokedBlock = ^(NSArray<NSString *> *urls) {
        NSSet *urlsSet = [NSSet setWithArray:urls];
        NSSet *expected = [NSSet setWithArray:@[expiredUrl1, expiredUrl2]];
        XCTAssertEqualObjects(expected, urlsSet);
    };
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for delete completion"];
    __weak CTFileDownloaderTests *weakSelf = self;
    self.fileDownloader.deleteCompletion = ^(NSDictionary<NSString *, id> * _Nonnull status) {
        XCTAssertNotNil([status objectForKey:expiredUrl1]);
        XCTAssertNotNil([status objectForKey:expiredUrl2]);
        
        NSDictionary *urlsExpiry = [@{
            @"url1": @(ts),
            @"url3": @(ts + 1)
        } mutableCopy];
        
        XCTAssertTrue([weakSelf.fileDownloader.urlsExpiry isEqualToDictionary:urlsExpiry]);
        [expectation fulfill];
    };
    
    long lastDeleted = ts - self.fileDownloader.fileExpiryTime - 1;
    self.fileDownloader.mockCurrentTimeInterval = ts;
    self.fileDownloader.urlsExpiry = [@{
        expiredUrl1: @(ts - 1),
        @"url1": @(ts),
        expiredUrl2: @(ts - 60),
        @"url3": @(ts + 1),
    } mutableCopy];
    [self.fileDownloader removeInactiveExpiredAssets:lastDeleted];
    [self waitForExpectations:@[expectation] timeout:2.0];
    self.fileDownloader.deleteFilesInvokedBlock = nil;
}

- (void)testUpdateFilesExpiry {
    long ts = (long)[[NSDate date] timeIntervalSince1970];
    self.fileDownloader.mockCurrentTimeInterval = ts;
    long expiry = ts + self.fileDownloader.fileExpiryTime;

    NSDictionary *status = @{
        @"url0": @(1),
        @"url1": @(0),
        @"url2": @(0),
        @"url3": @(1)
    };
    
    long previousExpiry = (ts - 100) + self.fileDownloader.fileExpiryTime;
    self.fileDownloader.urlsExpiry = [@{
        @"url0": @(previousExpiry),
        @"url2": @(previousExpiry),
        @"url4": @(previousExpiry)
    } mutableCopy];
    
    [self.fileDownloader updateFilesExpiry:status];
    
    NSMutableDictionary *expected = [@{
        @"url0": @(expiry),
        @"url2": @(previousExpiry),
        @"url3": @(expiry),
        @"url4": @(previousExpiry)
    } mutableCopy];
    
    XCTAssertEqualObjects(expected, self.fileDownloader.urlsExpiry);
}

- (void)testDeleteFiles {
    long ts = (long)[[NSDate date] timeIntervalSince1970];
    NSArray<NSString *> *urls = [self generateFileURLs:3];
    for (NSString *url in urls) {
        self.fileDownloader.urlsExpiry[url] = @(ts);
    }
    
    self.fileDownloader.mockCurrentTimeInterval = ts;
    //
    XCTAssertEqual(ts, [self.fileDownloader getLastDeletedTimestamp]);
    self.fileDownloader.mockCurrentTimeInterval = ts + 100;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Delete files."];
    [self.fileDownloader deleteFiles:@[urls[0], urls[1]] withCompletionBlock:^(NSDictionary<NSString *,id> * _Nonnull status) {
        XCTAssertEqualObjects(status[urls[0]], @1);
        XCTAssertEqualObjects(status[urls[1]], @1);
        
        NSDictionary *expectedExpiry = [@{
            urls[2]: @(ts)
        } mutableCopy];
        XCTAssertTrue([expectedExpiry isEqualToDictionary:self.fileDownloader.urlsExpiry]);
        
        XCTAssertEqualObjects(self.fileDownloader.urlsExpiry, [CTPreferences getObjectForKey:[self.fileDownloader storageKeyWithSuffix:CLTAP_FILE_URLS_EXPIRY_DICT]]);

        XCTAssertEqual(ts + 100, [self.fileDownloader getLastDeletedTimestamp]);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (void)testClearExpiredFiles {
    XCTestExpectation *expectation = [self expectationWithDescription:@"ClearAllFiles expired only triggers remove expired files."];
    self.fileDownloader.removeInactiveExpiredAssetsBlock = ^(long lastDeleted) {
        XCTAssertEqual(1, lastDeleted);
        [expectation fulfill];
    };
    [self.fileDownloader clearFileAssets:YES];
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (void)testClearAllFiles {
    NSArray<NSString *> *urlsExpiry = [self generateFileURLs:3];
    for (NSString *url in urlsExpiry) {
        self.fileDownloader.urlsExpiry[url] = @(1);
    }
    XCTestExpectation *expectation = [self expectationWithDescription:@"ClearAllFiles trigger delete files."];
    self.fileDownloader.deleteFilesInvokedBlock = ^(NSArray<NSString *> *urls) {
        NSSet *urlsSet = [NSSet setWithArray:urls];
        NSSet *expected = [NSSet setWithArray:urlsExpiry];
        XCTAssertEqualObjects(expected, urlsSet);
        [expectation fulfill];
    };
    [self.fileDownloader clearFileAssets:NO];
    [self waitForExpectations:@[expectation] timeout:1.0];
    self.fileDownloader.deleteFilesInvokedBlock = nil;
}

- (void)testClearAllFileAssets {
    // Download the file
    NSArray *urls = [self generateFileURLs:1];
    [self downloadFiles:urls];
    XCTAssertTrue([self.fileDownloader isFileAlreadyPresent:urls[0]]);
    
    // Clear all file assets
    XCTestExpectation *expectation = [self expectationWithDescription:@"Clear all assets"];
    __weak CTFileDownloaderTests *weakSelf = self;
    self.fileDownloader.deleteCompletion = ^(NSDictionary<NSString *,id> * _Nonnull status) {
        XCTAssertFalse([weakSelf.fileDownloader isFileAlreadyPresent:urls[0]]);
        [expectation fulfill];
    };
    
    [self.fileDownloader clearFileAssets:NO];
    [self waitForExpectations:@[expectation] timeout:2.5];
}

- (void)testFileDownloadCallbacksWhenFileIsAlreadyDownloading {
    // This test checks the file download callbacks when same url is already downloading.
    // Verified from adding logs that same url is not downloaded twice if download is in
    // progress for that url. Also callbacks are triggered when download is completed.
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Wait for first download callbacks"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Wait for second download callbacks"];
    
    NSArray *urls = [self generateFileURLs:3];
    [self.fileDownloader downloadFiles:@[urls[0], urls[1], urls[2]] withCompletionBlock:^(NSDictionary<NSString *,id> * _Nullable status) {
        XCTAssertTrue([self.fileDownloader isFileAlreadyPresent:urls[0]]);
        XCTAssertTrue([self.fileDownloader isFileAlreadyPresent:urls[1]]);
        XCTAssertTrue([self.fileDownloader isFileAlreadyPresent:urls[2]]);
        [expectation1 fulfill];
    }];
    [self.fileDownloader downloadFiles:@[urls[0], urls[1]] withCompletionBlock:^(NSDictionary<NSString *,id> * _Nullable status) {
        XCTAssertTrue([self.fileDownloader isFileAlreadyPresent:urls[0]]);
        XCTAssertTrue([self.fileDownloader isFileAlreadyPresent:urls[1]]);
        [expectation2 fulfill];
    }];
    [self waitForExpectations:@[expectation2, expectation1] timeout:2.0 enforceOrder:YES];
}

#pragma mark Private methods

// TODO: reuse from other test
- (void)addAllStubs {
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:fileURL];
    } withStubResponse:^HTTPStubsResponse*(NSURLRequest *request) {
        NSString *fileString = [request.URL absoluteString];
        NSString *fileType = [fileString pathExtension];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
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

- (void)downloadFiles:(NSArray *)urls  {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Download files"];
    [self.fileDownloader downloadFiles:urls withCompletionBlock:^(NSDictionary<NSString *,id> * _Nullable status) {
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:2.0];
}

// TODO: reuse from other test
- (NSArray<NSString *> *)generateFileURLs:(int)count {
    NSMutableArray *arr = [NSMutableArray new];
    for (int i = 0; i < count; i++) {
        NSString *urlString = [[NSString alloc] initWithFormat:@"https://clevertap.com/%@.%@",fileURL, fileTypes[i]];
        [arr addObject:urlString];
    }
    return arr;
}

@end