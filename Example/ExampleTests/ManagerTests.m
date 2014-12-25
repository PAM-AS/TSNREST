//
//  ManagerTests.m
//  Example
//
//  Created by Thomas Sunde Nielsen on 23.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TSNRESTManager.h"

@interface ManagerTests : XCTestCase

@property (nonatomic, strong) NSDictionary *exampleHeaders;

@end

@implementation ManagerTests

- (void)setUp {
    [super setUp];
    self.exampleHeaders = @{@"X-PAM-Current-Employee":@55, @"X-PAM-Current-User":@234, @"X-PAM-Current-Shop":@92};
}

- (void)tearDown {
    self.exampleHeaders = nil;
    [super tearDown];
}

- (void)testThatAddingCustomHeadersWorks {
    TSNRESTManager *manager = [[TSNRESTManager alloc] init];
    
    XCTAssert(self.exampleHeaders.count > 0, @"No example headers given, test would succeed when it shouldn't.");
    
    for (NSString *key in self.exampleHeaders) {
        id value = [self.exampleHeaders objectForKey:key];
        [manager setGlobalHeader:value forKey:key];
    }
    
    for (NSString *key in manager.customHeaders) {
        
        XCTAssertEqualObjects([manager.customHeaders objectForKey:key], [self.exampleHeaders objectForKey:key], @"Header values wasn't equal: %@ != %@", [manager.customHeaders objectForKey:key], [self.exampleHeaders objectForKey:key]);
    }
}

- (void)testThatAddingCustomHeaderFromNSUserDefaultsWorks {
    NSString *testKey = @"testKey";
    NSString *testValue = @"a value";
    [[NSUserDefaults standardUserDefaults] setObject:testValue forKey:testKey];
    TSNRESTManager *manager = [[TSNRESTManager alloc] init];
    [manager setGlobalHeaderFromSettingsKey:testKey forKey:testKey];
    
    XCTAssertEqualObjects([manager.customHeaders objectForKey:testKey], testValue, @"Setting header from setting didn't work. Expected %@, got %@", testValue, [manager.customHeaders objectForKey:testKey]);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:testKey];
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
