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
#import "TSNRESTManager.h"

@implementation NSManagedObject (TSNRESTFetching)

+ (NSManagedObject *)findOrCreateBySystemId:(NSNumber *)systemid inContext:(NSManagedObjectContext *)context {
    if (!context)
        context = [NSManagedObjectContext MR_contextForCurrentThread];
    NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
    NSManagedObject *object = [self MR_findFirstByAttribute:idKey withValue:systemid inContext:context];
    if (!object) {
        object = [self MR_createEntityInContext:context];
        [object setValue:systemid forKey:idKey];
    }
    return object;
}

@end
