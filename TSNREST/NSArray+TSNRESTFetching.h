//
//  NSArray+TSNRESTFetching.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.02.15.
//
//

#import <Foundation/Foundation.h>

@interface NSArray (TSNRESTFetching)

- (void)reloadContainedManagedObjects;
- (void)reloadContainedManagedObjectsWithCompletion:(void(^)(NSArray *updatedObjects))completion;

@end
