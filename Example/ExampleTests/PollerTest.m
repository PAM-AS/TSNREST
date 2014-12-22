//
//  PollerTest.m
//  Example
//
//  Created by Thomas Sunde Nielsen on 22.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TSNRESTPoller.h"

@interface PollerTest : XCTestCase

@property (nonatomic, strong) TSNRESTPoller *poller;

@end

@implementation PollerTest

- (void)setUp {
    [super setUp];
    self.poller = [TSNRESTPoller new];
}

- (void)tearDown {
    [self.poller removeAllPollers];
    self.poller = nil;
    [super tearDown];
}

- (void)testThatPollerCanAddPollBlock {
    [self.poller addPollerForKey:@"testKey" poll:^{
        NSLog(@"Pong");
    } interval:1];
    
    XCTAssert(self.poller.countOfActiveTimers == 1, @"Could not create a poller (count is %li)", self.poller.countOfActiveTimers);
}

- (void)testThatPollerCanRemovePollBlock {
    NSString *key = @"testKey";
    [self.poller addPollerForKey:key poll:^{
        NSLog(@"Pong");
    } interval:1];
    
    NSString *key2 = @"testKey2";
    [self.poller addPollerForKey:key2 poll:^{
        NSLog(@"Pong");
    } interval:1];
    
    [self.poller removePollerForKey:key];
    
    XCTAssert(self.poller.countOfActiveTimers == 1, @"Could not remove a poller (count is %li)", self.poller.countOfActiveTimers);
}

- (void)testThatPollerCanRemoveAllPollBlocks {
    NSString *key = @"testKey";
    [self.poller addPollerForKey:key poll:^{
        NSLog(@"Pong");
    } interval:1];
    
    NSString *key2 = @"testKey2";
    [self.poller addPollerForKey:key2 poll:^{
        NSLog(@"Pong");
    } interval:1];
    
    [self.poller removeAllPollers];
    
    XCTAssert(self.poller.countOfActiveTimers == 0, @"Could not remove all pollers (count is %li)", self.poller.countOfActiveTimers);
}

//
//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
