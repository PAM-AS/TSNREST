//
//  Product.h
//  Example
//
//  Created by Thomas Sunde Nielsen on 30.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Brand, Image, Shop;

@interface Product : NSManagedObject

@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) NSString * descr;
@property (nonatomic, retain) NSNumber * dirty;
@property (nonatomic, retain) NSNumber * inventory;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * priceGross;
@property (nonatomic, retain) NSNumber * systemId;
@property (nonatomic, retain) NSNumber * visible;
@property (nonatomic, retain) Brand *brand;
@property (nonatomic, retain) Shop *shop;
@property (nonatomic, retain) NSSet *images;
@end

@interface Product (CoreDataGeneratedAccessors)

- (void)addImagesObject:(Image *)value;
- (void)removeImagesObject:(Image *)value;
- (void)addImages:(NSSet *)values;
- (void)removeImages:(NSSet *)values;

@end
