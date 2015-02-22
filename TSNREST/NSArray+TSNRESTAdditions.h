//
//  NSArray+TSNRESTAdditions.h
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 12.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "TSNRESTManager.h"

@interface NSArray (TSNRESTAdditions)

/**
 Fault (load if not already loaded) group of object from server.
 This checks if objects are loaded or just referenced by a relation from another object.
 
 @param sideloads is optional, allowing to append ?include=string1,string2 for the server to sideload additional objects.
 */
- (void)faultGroup;
- (void)faultGroupWithSideloads:(NSArray *)sideloads;

/**
 refreshGroup allows you to refresh all NSManagedObjects in the array from the server. It currently uses the syntax ids=1,2,3.
 
 @param sideloads is optional, allowing to append ?include=string1,string2 for the server to sideload additional objects.
 */
- (void)refreshGroup;
- (void)refreshGroupWithSideloads:(NSArray *)sideloads;

/**
 Save contained NSManagedObjects to the local store as well as to the server. All objects are saved individually.
 
 You can optionally add callback blocks that will be called when all saves are completed.
 
 @param successBlock Called if all saves succeed
 @param failureBlock Called if one or more of the saves fail
 @param finallyBlock Called when all saves are done, regardless of failure or success
 */
- (void)saveAndPersistContainedNSManagedObjects;
- (void)saveAndPersistContainedNSManagedObjectsWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock;

@end
