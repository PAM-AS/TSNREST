//
//  NSArray+TSNRESTAdditions.h
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 12.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#define MR_SHORTHAND 1

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "CoreData+MagicalRecord.h"
#import "TSNRESTManager.h"

@interface NSArray (TSNRESTAdditions)

- (void)faultGroup;
- (void)faultGroupWithSideloads:(NSArray *)sideloads;
- (void)refreshGroup;
- (void)refreshGroupWithSideloads:(NSArray *)sideloads;
- (void)saveAndPersistContainedNSManagedObjects;
- (void)saveAndPersistContainedNSManagedObjectsWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock;
- (void)persistContainedNSManagedObjects DEPRECATED_ATTRIBUTE;
- (void)persistContainedNSManagedObjectsWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock DEPRECATED_ATTRIBUTE;

@end
