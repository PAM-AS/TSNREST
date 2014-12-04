//
//  NSDictionary+TSNRESTDeserializer.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import "NSDictionary+TSNRESTDeserializer.h"
#import "NSArray+TSNRESTDeserializer.h"
#import "NSObject+PropertyClass.h"
#import "NSString+TSNRESTCasing.h"
#import "NSManagedObject+TSNRESTFetching.h"

@implementation NSDictionary (TSNRESTDeserializer)

- (NSManagedObject *)mapToObject:(NSManagedObject *)inputObject withMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)context optimize:(BOOL)optimize {
    NSManagedObject *object = [inputObject MR_inContext:context];
#if DEBUG
    if (object)
        NSLog(@"Updating %@ %@ (%@)", NSStringFromClass([map classToMap]), [self objectForKey:@"id"], [object valueForKey:@"systemId"]);
    else
        NSLog(@"Adding %@ %@", NSStringFromClass([map classToMap]), [self objectForKey:@"id"]);
#endif
    
    if (optimize && object && [object respondsToSelector:NSSelectorFromString(@"updatedAt")] && (![object respondsToSelector:NSSelectorFromString(@"dirty")] || ![[object valueForKey:@"dirty"] isEqualToNumber:@2]))
    {
        NSDate *objectDate = [object valueForKey:@"updatedAt"];
        NSDate *webDate = [[[TSNRESTManager sharedManager] ISO8601Formatter] dateFromString:[self objectForKey:[[map objectToWeb] valueForKey:@"updatedAt"]]];
        if (webDate && [objectDate isKindOfClass:[NSDate class]] && [objectDate isEqualToDate:webDate])
        {
#if DEBUG
            NSLog(@"Skipping object that hasn't been updated since %@", webDate);
#endif
            return object;
        }
    }
    
    // SystemId custom
    if ([object respondsToSelector:NSSelectorFromString(@"systemId")])
        [object setValue:[self objectForKey:@"id"] forKey:@"systemId"];
    if ([object respondsToSelector:NSSelectorFromString(@"dirty")])
    {
        if ([[object valueForKey:@"dirty"] integerValue] == 1)
        {
            [(NSManagedObject *)object saveAndPersist];
#if DEBUG
            NSLog(@"Object was dirty, attempting to persist it.");
#endif
            return object;
        }
        else
            [object setValue:@0 forKey:@"dirty"];
    }
    
    

    // Objectmapping
    for (NSString *key in [map objectToWeb])
    {
        NSString *webKey = [[map objectToWeb] objectForKey:key];

        
        
        // Enums
        if ([[map enumMaps] valueForKey:key])
        {
            NSDictionary *enumMap = [[map enumMaps] valueForKey:key];
            id value = [[enumMap allKeysForObject:[self valueForKey:webKey]] firstObject];
            [object setValue:value forKey:key];
        }
        
        
        
        // Check if this is an embedded record
        else if ([[self valueForKey:webKey] isKindOfClass:[NSArray class]] && [[[self valueForKey:webKey] objectAtIndex:0] isKindOfClass:[NSDictionary class]])
        {
            TSNRESTObjectMap *oMap = [[TSNRESTManager sharedManager] objectMapForServerPath:webKey];
            if (oMap)
            {
                [(NSArray *)[self valueForKey:webKey] deserializeWithMap:oMap inContext:context optimize:optimize];
            }
        }
        
        
        // Check if this is a single relation. If so, be its cupid.
        else if ([[object classOfPropertyNamed:key] isSubclassOfClass:[NSManagedObject class]] && [self valueForKey:webKey] != [NSNull null])
        {
            NSManagedObject *classObject = nil;
            classObject = [[object classOfPropertyNamed:key] MR_findFirstByAttribute:@"systemId" withValue:[self valueForKey:webKey] inContext:context];
            
            if (!classObject) // Create a new, empty object and set system id
            {
#if DEBUG
                NSLog(@"Created new %@ with id %@ and added it to %@ %@", [object classOfPropertyNamed:key], [self valueForKey:webKey], NSStringFromClass([object class]), [object valueForKey:@"systemId"]);
#endif
                classObject = [[object classOfPropertyNamed:key] MR_createEntityInContext:context];
                if ([classObject respondsToSelector:NSSelectorFromString(@"systemId")])
                    [classObject setValue:[self valueForKey:webKey] forKey:@"systemId"];
                if ([classObject respondsToSelector:NSSelectorFromString(@"dirty")]) // Object needs to load fault
                    [classObject setValue:@2 forKey:@"dirty"];
#if DEBUG
                else
                    NSLog(@"Warning: %@ is not faultable ('dirty' key missing)", NSStringFromClass([classObject class]));
#endif
            }
            [object setValue:classObject forKey:key];
        }
        
        
        
        // Check if this is a multiple-relation
        else if ([[object classOfPropertyNamed:key] isSubclassOfClass:[NSSet class]] && [[self valueForKey:webKey] isKindOfClass:[NSArray class]]) {
            // Remove existing
            NSSet *existing = [object valueForKey:key];
            
            // http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
            SEL removeSelector = NSSelectorFromString([NSString stringWithFormat:@"remove%@:", [key camelCasedString]]);
            IMP imp = [object methodForSelector:removeSelector];
            void (*func)(id, SEL, NSSet *) = (void *)imp;
            func(object, removeSelector, existing);
            
            // Create set to insert
            NSArray *ids = [self valueForKey:webKey];
            __block NSMutableSet *objects = [[NSMutableSet alloc] initWithCapacity:ids.count];
            [ids enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSNumber *systemId = (NSNumber *)obj;
                Class relationClass = (Class)[[map keyClasses] objectForKey:key];
                NSManagedObject *relation = [relationClass findOrCreateBySystemId:systemId inContext:context];
                [objects addObject:relation];
            }];
            
            // Insert new set if count is more than 0.
            if (objects.count > 0) {
                SEL addSelector = NSSelectorFromString([NSString stringWithFormat:@"add%@:", [key camelCasedString]]);
                IMP imp = [object methodForSelector:addSelector];
                void (*func)(id, SEL, NSSet *) = (void *)imp;
                func(object, addSelector, objects);
            }
        }
        
        
        
        // Special case for dates: Need to be converted from a string containing ISO8601
        else if ([object classOfPropertyNamed:key] == [NSDate class])
        {
            NSDate *date = [[[TSNRESTManager sharedManager] ISO8601Formatter] dateFromString:[self objectForKey:webKey]]; // This method also supports epoch timestamps.
            [object setValue:date forKey:key];
        }
        
        
        
        // Assume NSString or NSNumber for everything else.
        else if ([self valueForKey:webKey] != [NSNull null] && [[self valueForKey:webKey] isKindOfClass:[object classOfPropertyNamed:key]])
        {
            [object setValue:[self objectForKey:webKey] forKey:key];
        }
    }
    
    if (map.mappingBlock && object)
        map.mappingBlock(object, context, self);
    
    return object;
}

@end
