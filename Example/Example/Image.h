//
//  Image.h
//  Example
//
//  Created by Thomas Sunde Nielsen on 30.12.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Product;

@interface Image : NSManagedObject

@property (nonatomic, retain) NSNumber * systemId;
@property (nonatomic, retain) NSNumber * width;
@property (nonatomic, retain) NSNumber * dirty;
@property (nonatomic, retain) NSNumber * height;
@property (nonatomic, retain) NSString * sha1;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSNumber * sortOrder;
@property (nonatomic, retain) NSNumber * visible;
@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) Product *product;

@end
