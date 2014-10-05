//
//  NSSet+TSNRESTAdditions.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 16.07.14.
//
//

#import "NSSet+TSNRESTAdditions.h"
#import "NSArray+TSNRESTAdditions.h"

@implementation NSSet (TSNRESTAdditions)

- (void)faultAllIfNeeded
{
    [[self allObjects] faultGroup];
}

- (void)saveAndPersistContainedNSManagedObjects
{
    [self.allObjects saveAndPersistContainedNSManagedObjects];
}

- (void)saveAndPersistContainedNSManagedObjectsWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock
{
    [self.allObjects saveAndPersistContainedNSManagedObjectsWithSuccess:successBlock failure:failureBlock finally:finallyBlock];
}

- (NSSet *)inContext:(NSManagedObjectContext *)context
{
    NSMutableSet *newSet = [[NSMutableSet alloc] init];
    for (id object in self)
    {
        if ([object isKindOfClass:[NSManagedObject class]])
            [newSet addObject:[(NSManagedObject *)object MR_inContext:context]];
    }
    return [NSSet setWithSet:newSet];
}

@end
