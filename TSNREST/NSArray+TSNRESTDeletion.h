//
//  NSArray+TSNRESTDeletion.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.02.15.
//
//

#import <Foundation/Foundation.h>

@interface NSArray (TSNRESTDeletion)

/*
 Note: Although you get a list of deleted ids in the completion block, this doesn't mean that they need to be deleted manually, nor that they have been deleted. It's just a list of objects that are being double-checked for deletion (pinging for 404 against the server).
 */
- (void)checkContainedManagedObjectsForDeletion;
- (void)checkContainedManagedObjectsForDeletionWithCompletion:(void (^)(BOOL anyDeleted, NSArray *deletedIds))completion;

@end
