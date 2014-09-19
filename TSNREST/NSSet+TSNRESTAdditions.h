//
//  NSSet+TSNRESTAdditions.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 16.07.14.
//
//

#import <Foundation/Foundation.h>
#import "TSNRESTManager.h"

@interface NSSet (TSNRESTAdditions)

- (void)faultAllIfNeeded;
- (void)saveAndPersistContainedNSManagedObjects;
- (void)saveAndPersistContainedNSManagedObjectsWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock;
- (NSSet *)inContext:(NSManagedObjectContext *)context;

@end
