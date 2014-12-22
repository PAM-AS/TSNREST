//
//  Product.h
//  Example
//
//  Created by Thomas Sunde Nielsen on 22.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Brand, Shop;

@interface Product : NSManagedObject

@property (nonatomic, retain) NSNumber * systemId;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * descr;
@property (nonatomic, retain) NSNumber * inventory;
@property (nonatomic, retain) NSNumber * priceGross;
@property (nonatomic, retain) NSNumber * visible;
@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) Shop *shop;
@property (nonatomic, retain) Brand *brand;

@end
