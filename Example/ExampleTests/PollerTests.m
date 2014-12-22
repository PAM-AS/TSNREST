//
//  PollerTest.m
//  Example
//
//  Created by Thomas Sunde Nielsen on 22.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TSNRESTPoller.h"

@interface PollerTests : XCTestCase

@property (nonatomic, strong) TSNRESTPoller *poller;

@end

@implementation PollerTests

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

- (void)testThatPollerCanReturnCorrectPoller {
    NSString *key = @"testKey";
    NSTimer *timer = [self.poller addPollerForKey:key poll:^{
        NSLog(@"Pong");
    } interval:1];
    XCTAssertNotNil(timer, @"addPollerForKey:poll:interval: didn't return a timer");
    XCTAssertEqual(timer, [self.poller timerForKey:key], @"timerForKey: didn't return the correct timer (returned %@)", [self.poller timerForKey:key]);
}

- (void)testThatPollerOverwritesOldPollersWithSameKey {
    NSString *key = @"testKey";
    NSTimer *firstTimer = [self.poller addPollerForKey:key poll:^{
        NSLog(@"Ping");
    } interval:1];
    NSTimer *secondTimer = [self.poller addPollerForKey:key poll:^{
        NSLog(@"Pong");
    } interval:1];
    XCTAssertNotEqual(firstTimer, secondTimer, @"Second timer didn't overwrite the first, they are alike.");
    XCTAssert(self.poller.countOfActiveTimers == 1, @"Count of timers is wrong. It's %li, but should be 1", self.poller.countOfActiveTimers);
    XCTAssertEqual(secondTimer, [self.poller timerForKey:key], @"timerForKey: didn't return the second timer (returned %@)", [self.poller timerForKey:key]);
}

- (void)testThatPollerGetsInvalidatedWhenRemoved {
    NSString *key = @"testKey";
    NSTimer *firstTimer = [self.poller addPollerForKey:key poll:^{
        NSLog(@"Ping");
    } interval:1];
    [self.poller removePollerForKey:key];
    XCTAssert(!firstTimer.isValid, @"Poller didn't invalidate the timer when removing it.");
}

//
//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
