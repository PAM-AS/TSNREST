//
//  ObjectMapTests.m
//  Example
//
//  Created by Thomas Sunde Nielsen on 25.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TSNRESTManager.h"
#import "TSNRESTObjectMap.h"
#import "Product.h"

@interface ObjectMapTests : XCTestCase

@end

@implementation ObjectMapTests

- (void)setUp {
    [super setUp];
    [[TSNRESTManager sharedManager] addObjectMap:[TSNRESTObjectMap autogeneratedMapForClass:[Product class]]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testThatAutogeneratedObjectMapGetsCorrectServerPath {
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[Product class]];
    NSString *expectedPath = @"products";
    XCTAssertEqualObjects(map.serverPath, expectedPath, @"Server path is wrong, got %@ expected %@", map.serverPath, expectedPath);
}

- (void)testThatAutomapMapsCorrectly {
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[Product class]];
    XCTAssertEqualObjects([map.objectToWeb objectForKey:@"name"], @"name", @"Equal keys (no camelCase) wasn't mapped correctly.");
    XCTAssertEqualObjects([map.objectToWeb objectForKey:@"shop"], @"shop_id", @"Relationship keys (should get _id) wasn't mapped correctly. Got %@", [map.objectToWeb objectForKey:@"shop"]);
    XCTAssertEqualObjects([map.objectToWeb objectForKey:@"priceGross"], @"price_gross", @"Automapping camelCase failed, got %@", [map.objectToWeb objectForKey:@"priceGross"]);
}

@end
