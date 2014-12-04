//
//  NSManagedObject+TSNRESTFetching.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import "NSManagedObject+TSNRESTFetching.h"
#import "NSManagedObject+MagicalFinders.h"
#import "NSManagedObject+MagicalRecord.h"
#import "NSManagedObjectContext+MagicalThreading.h"

@implementation NSManagedObject (TSNRESTFetching)

+ (NSManagedObject *)findOrCreateBySystemId:(NSNumber *)systemid inContext:(NSManagedObjectContext *)context {
    if (!context)
        context = [NSManagedObjectContext MR_contextForCurrentThread];
    NSManagedObject *object = [self MR_findFirstByAttribute:@"systemId" withValue:systemid inContext:context];
    if (!object) {
        object = [self MR_createEntityInContext:context];
        [object setValue:systemid forKey:@"systemId"];
    }
    return object;
}

@end
