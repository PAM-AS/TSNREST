//
//  ConfigTests.m
//  Example
//
//  Created by Thomas Sunde Nielsen on 23.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TSNRESTManager.h"

@interface ConfigTests : XCTestCase

@end

@implementation ConfigTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [[TSNRESTManager sharedManager] setConfiguration:nil]; // Reset config
    [super tearDown];
}

- (void)testThatConfigLocalIdNameReturnsADefault {
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    XCTAssertEqualObjects(manager.configuration.localIdName, @"systemId", @"Default config doesn't return the correct local id name");
}

- (void)testThatLocalIdNameCanBeOverwritten {
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    NSString *newName = @"serverId";
    manager.configuration.localIdName = newName;
    XCTAssertEqualObjects(manager.configuration.localIdName, newName, @"Could not overwrite localIdName, wrote %@ but got %@ in return.", newName, manager.configuration.localIdName);
}

- (void)testThatNoBaseURLIsSetByDefault {
    // This test is mainly here as a reminder to add a new test if we ever create a default.
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    XCTAssertNil(manager.configuration.baseURL, @"Base url isn't nil, it's %@", manager.configuration.baseURL);
}

- (void)testBaseURLSettingAndGetting {
    NSURL *url = [NSURL URLWithString:@"http://pam.no/api/v1"];
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    [manager.configuration setBaseURL:url];
    XCTAssertEqualObjects(url, manager.configuration.baseURL, @"URLs aren't alike: %@ != %@", url.absoluteString, manager.configuration.baseURL.absoluteString);
}

- (void)testSettingAndGettingUserClass {
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    Class userClass = [NSDictionary class];
    manager.configuration.userClass = userClass;
    XCTAssertEqualObjects(userClass, manager.configuration.userClass, @"User class didn't get set correctly - expected %@, got %@", NSStringFromClass(userClass), NSStringFromClass(manager.configuration.userClass));
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
