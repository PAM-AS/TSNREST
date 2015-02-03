//
//  NSArray+TSNRESTDeletion.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.02.15.
//
//

#import "NSArray+TSNRESTDeletion.h"
#import "NSArray+TSNRESTAdditions.h"
#import "NSArray+TSNRESTFetching.h"

@implementation NSArray (TSNRESTDeletion)

- (void)checkContainedManagedObjectsForDeletion {
    [self checkContainedManagedObjectsForDeletionWithCompletion:nil];
}


- (void)checkContainedManagedObjectsForDeletionWithCompletion:(void (^)(BOOL anyDeleted, NSArray *deletedIds))completion {
    if (self.count == 0) {
        if (completion)
            completion(NO, nil);
        return;
    }
    
    NSArray *currentIds = [self valueForKey:TSNRESTManager.sharedManager.configuration.localIdName];
    Class class = [[self firstObject] class];
    
    [self reloadContainedManagedObjectsWithCompletion:^(NSArray *updatedObjects) {
        if (!updatedObjects || updatedObjects.count == 0) {
            if (completion)
                completion(NO, nil);
            return;
        }
        
        NSArray *arrayOfReturnedIds = [updatedObjects valueForKey:TSNRESTManager.sharedManager.configuration.localIdName];
        
        NSMutableSet *existingIds = [NSMutableSet setWithArray:currentIds];
        NSSet *returnedIds = [NSSet setWithArray:arrayOfReturnedIds];
        
        [existingIds minusSet:returnedIds];
        if (existingIds.count > 0) {
            NSManagedObjectContext *context = [NSManagedObjectContext MR_context];
            [context performBlock:^{
                for (NSNumber *systemId in existingIds) {
                    NSManagedObject *object = [class MR_findFirstByAttribute:TSNRESTManager.sharedManager.configuration.localIdName withValue:systemId inContext:context];
                    [object checkForDeletion:nil];
                }
            }];
            if (completion)
                completion(YES, [existingIds allObjects]);
        } else {
            if (completion)
                completion(NO, nil);
        }
    }];
}

@end
