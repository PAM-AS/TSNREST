//
//  SerializerTests.m
//  Example
//
//  Created by Thomas Sunde Nielsen on 23.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSManagedObject+TSNRESTSerializer.h"
#import "NSManagedObject+MagicalRecord.h"
#import "TSNRESTManager.h"
#import "Shop.h"
#import "Brand.h"
#import "Product.h"

@interface SerializerTests : XCTestCase

@property (nonatomic, strong) Product *testProduct;

@end

@implementation SerializerTests

- (void)setUp {
    [super setUp];
    Product *product = [Product MR_createEntity];
    product.systemId = @42;
    product.name = @"Testproduct";
    product.descr = @"Testproduct description";
    Shop *shop = [Shop MR_createEntity];
    shop.systemId = @43;
    product.shop = shop;
    Brand *brand = [Brand MR_createEntity];
    brand.systemId = @44;
    product.brand = brand;
    product.visible = @YES;
    product.priceGross = @199000;
    product.inventory = @42;
    product.createdAt = [NSDate date];
    self.testProduct = product;
    
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    [manager addObjectMap:[TSNRESTObjectMap autogeneratedMapForClass:[Product class]]];
}

- (void)tearDown {
    Product *product = self.testProduct;
    [product MR_deleteEntity];
    [product.shop MR_deleteEntity];
    [product.brand MR_deleteEntity];
    [super tearDown];
}

- (void)testThatDeserializerCreatesCorrectJSON {
    Product *product = self.testProduct;
    
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    
    NSDictionary *expectedResult = @{@"id":product.systemId,
                                     @"name":product.name,
                                     @"descr":product.descr,
                                     @"shop_id":product.shop.systemId,
                                     @"brand_id":product.brand.systemId,
                                     @"visible":product.visible,
                                     @"price_gross":product.priceGross,
                                     @"inventory":product.inventory,
                                     @"created_at":[manager.ISO8601Formatter stringFromDate:product.createdAt]};
    
    NSError *error = [[NSError alloc] init];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:[product jsonDataRepresentation] options:0 error:&error];
    XCTAssert([result isEqualToDictionary:expectedResult], @"Dictionaries aren't equal: %@ vs %@", result, expectedResult);
    
    
}

- (void)testSerializerPerformance {
    // This is an example of a performance test case.
    [self measureBlock:^{
        [self.testProduct jsonDataRepresentation];
    }];
}

@end
