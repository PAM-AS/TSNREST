//
//  TSNRESTParser.m
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 04.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import "TSNRESTParser.h"
#import "NSObject+PropertyClass.h"
#import "NSDate+SAMAdditions.h"

@implementation TSNRESTParser

+ (BOOL)parseAndPersistDictionary:(NSDictionary *)dict
{
    return [self parseAndPersistDictionary:dict withCompletion:nil];
}

+ (BOOL)parseAndPersistDictionary:(NSDictionary *)dict withCompletion:(void (^)())completion
{
    return [self parseAndPersistDictionary:dict withCompletion:completion forObject:nil];
}

+ (BOOL)parseAndPersistDictionary:(NSDictionary *)dict withCompletion:(void (^)())completion forObject:(id)inputObject
{
    id __block object = inputObject;
    
#if DEBUG
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    int objects = 0;
#endif
    
    for (NSString *dictKey in dict)
    {
        TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForServerPath:dictKey];
        if (map)
        {
#if DEBUG
            NSLog(@"Found map for %@", dictKey);
#endif
            NSArray *jsonData = [dict objectForKey:dictKey];
#if DEBUG
            objects += jsonData.count;
#endif
            
            if (object && [object valueForKey:@"systemId"] == nil && [map classToMap] == [object class] && jsonData.count == 1)
            {
                dispatch_sync([[TSNRESTManager sharedManager] serialQueue], ^{
                    [MagicalRecord saveUsingCurrentThreadContextWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                        if ([[jsonData objectAtIndex:0] valueForKey:@"id"])
                        {
                            id existingObject = [[object class] findFirstByAttribute:@"systemId" withValue:[[jsonData objectAtIndex:0] valueForKey:@"id"] inContext:localContext];
                            
                            // Not quite sure why this catches things that the Core Data query above does not, but we need it to avoid bugs.
                            if (existingObject)
                                object = existingObject;
                        }
                        [[object inContext:localContext] setValue:[[jsonData objectAtIndex:0] valueForKey:@"id"] forKey:@"systemId"];
                    }];
                });
            }
            
            [self parseAndPersistArray:jsonData withObjectMap:map];
            
        }
    }
    
#if DEBUG
    NSLog(@"Parsing %lu arrays (%i objects) took %f", (unsigned long)dict.count, objects, [NSDate timeIntervalSinceReferenceDate] - start);
#endif
    
    
    if (completion)
        completion();
    
    dispatch_async(dispatch_get_main_queue(), ^{
#if DEBUG
        NSLog(@"Notifying everyone that new data is here, Praise TFSM");
#endif
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"newData" object:[dict allKeys]];
    });
    return YES;
}


+ (BOOL)parseAndPersistArray:(NSArray *)array withObjectMap:(TSNRESTObjectMap *)map
{
    NSLog(@"Starting Magic block in parseAndPersistArray for map %@", NSStringFromClass([map classToMap]));
    dispatch_sync([[TSNRESTManager sharedManager] serialQueue], ^{
        [MagicalRecord saveUsingCurrentThreadContextWithBlockAndWait:^(NSManagedObjectContext *localContext) {
            [self parseAndPersistArray:array withObjectMap:map inContext:localContext];
        }];
    });
    NSLog(@"Stopping Magic block in parseAndPersistArray for map %@", NSStringFromClass([map classToMap]));
    return YES;
}

+ (void)parseAndPersistArray:(NSArray *)array withObjectMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)localContext
{
    
#if DEBUG
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
#endif
    
    NSArray *existingObjects = [[map classToMap] findAll];
    
    NSArray *existingIds = [existingObjects valueForKey:@"systemId"];
    NSSet *newSet = [NSSet setWithArray:[array valueForKey:@"id"]?:@[]];
    NSMutableSet *existingSet = [NSMutableSet setWithArray:existingIds?:@[]];
    [existingSet intersectSet:newSet];
    
    /*
     Shortcut if we have no dirty items, no new items, and the object map says shouldIgnoreUpdates.
     
     Checking logic:
     If all objects are found locally, newSet.count and existingSet.count
     should be equal (intersect of local and new items, equal to new items).
     
     */
    if (map.shouldIgnoreUpdates && newSet.count == existingSet.count && [[existingObjects lastObject] respondsToSelector:NSSelectorFromString(@"dirty")])
    {
        NSSet *dirtyKeys = [NSSet setWithArray:[existingObjects valueForKey:@"dirty"]];
        NSLog(@"Checking dirty keys: %@", dirtyKeys);
        if (![dirtyKeys member:@1] && ![dirtyKeys member:@2])
        {
#if DEBUG
            NSLog(@"No objects of type %@ has been updated. Skipping %i objects.", NSStringFromClass([map classToMap]), array.count);
#endif
            return;
        }
    }
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"systemId" ascending:YES];
    NSEnumerator *existingEnumerator = [[existingObjects sortedArrayUsingDescriptors:@[sortDescriptor]] objectEnumerator];
    
    sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES];
    NSEnumerator *newEnumerator = [[array sortedArrayUsingDescriptors:@[sortDescriptor]] objectEnumerator];
    
    NSDictionary *jsonObject = [newEnumerator nextObject];
    id existingObject = [existingEnumerator nextObject];
    
    while (jsonObject) {
        
        // while (id != id)
            // nextObject
        while (existingObject && [[jsonObject objectForKey:@"id"] intValue] > [[existingObject valueForKey:@"systemId"] intValue]) {
            existingObject = [existingEnumerator nextObject];
        }
        
        id object = nil;
        
        if (existingObject && [[existingObject valueForKey:@"systemId"] integerValue] == [[jsonObject objectForKey:@"id"] integerValue])
            object = existingObject;
        else
        {
            object = [[map classToMap] createInContext:localContext];
            [object setValue:[jsonObject objectForKey:@"id"] forKey:@"systemId"];
        }
        
        [TSNRESTParser mapDict:jsonObject toObject:object withMap:map inContext:localContext];
        
        jsonObject = [newEnumerator nextObject];
    }
    
#if DEBUG
    NSLog(@"Parsing %lu objects of type %@ took %f seconds", (unsigned long)array.count, NSStringFromClass([map classToMap]), [NSDate timeIntervalSinceReferenceDate] - start);
#endif
}

+ (void)mapDict:(NSDictionary *)dict toObject:(id)object withMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)context
{
#if DEBUG
    /*
     Start the loop by logging what object we are adding.
     */
    if (object)
        NSLog(@"Updating %@ %@ (%@)", NSStringFromClass([map classToMap]), [dict objectForKey:@"id"], [object valueForKey:@"systemId"]);
    else
        NSLog(@"Adding %@ %@", NSStringFromClass([map classToMap]), [dict objectForKey:@"id"]);
#endif
    
    if ([object respondsToSelector:NSSelectorFromString(@"updatedAt")] && (![object respondsToSelector:NSSelectorFromString(@"dirty")] || ![[object valueForKey:@"dirty"] isEqualToNumber:@2]))
    {
        NSDate *objectDate = [object valueForKey:@"updatedAt"];
        NSDate *webDate = [[[TSNRESTManager sharedManager] ISO8601Formatter] dateFromString:[dict objectForKey:[[map objectToWeb] valueForKey:@"updatedAt"]]];
        if (webDate && [objectDate isKindOfClass:[NSDate class]] && [objectDate isEqualToDate:webDate])
        {
            return;
        }
    }
    
    // Duplicate avoidance (only works if server actually returns the uuid)
    if ([object respondsToSelector:NSSelectorFromString(@"uuid")] && [dict objectForKey:@"uuid"] && ![[object valueForKey:@"uuid"] isEqualToString:[dict objectForKey:@"uuid"]])
        return;
        
    
    if ([object respondsToSelector:NSSelectorFromString(@"systemId")])
        [object setValue:[dict objectForKey:@"id"] forKey:@"systemId"];
    if ([object respondsToSelector:NSSelectorFromString(@"dirty")])
    {
        if ([[object valueForKey:@"dirty"] integerValue] == 1)
        {
            [(NSManagedObject *)object persist];
            return;
        }
        else
            [object setValue:@0 forKey:@"dirty"];
    }
    
    for (NSString *key in [map objectToWeb])
    {
        NSString *webKey = [[map objectToWeb] objectForKey:key];
        
        if ([[map enumMaps] valueForKey:key])
        {
            NSDictionary *enumMap = [[map enumMaps] valueForKey:key];
            id value = [[enumMap allKeysForObject:[dict valueForKey:webKey]] firstObject];
            [object setValue:value forKey:key];
            NSLog(@"Found enum map for %@. set value to %@", key, value);
        }
        
        // Check if this is a relation to another object
        else if ([[dict valueForKey:webKey] isKindOfClass:[NSArray class]] && [[[dict valueForKey:webKey] objectAtIndex:0] isKindOfClass:[NSDictionary class]])
        {
            TSNRESTObjectMap *oMap = [[TSNRESTManager sharedManager] objectMapForServerPath:webKey];
            if (oMap)
            {
#if DEBUG
                NSLog(@"Found object map for %@", oMap.serverPath);
#endif
                [self parseAndPersistArray:[dict valueForKey:webKey] withObjectMap:oMap inContext:context];
            }
        }
        else if ([[object classOfPropertyNamed:key] isSubclassOfClass:[NSManagedObject class]] && [dict valueForKey:webKey] != [NSNull null])
        {
            // NSLog(@"Adding %@ (%@) to %@ %@", key, [dict valueForKey:webKey], NSStringFromClass([map classToMap]), [dict objectForKey:@"id"]);
            id classObject = nil;
            classObject = [[object classOfPropertyNamed:key] findFirstByAttribute:@"systemId" withValue:[dict valueForKey:webKey] inContext:context];
            
            if (!classObject) // Create a new, empty object and set system id
            {
#if DEBUG
                NSLog(@"Created new %@ with id %@ and added it to %@ %@", [object classOfPropertyNamed:key], [dict valueForKey:webKey], NSStringFromClass([object class]), [object valueForKey:@"systemId"]);
#endif
                classObject = [[object classOfPropertyNamed:key] createInContext:context];
                if ([classObject respondsToSelector:NSSelectorFromString(@"systemId")])
                    [classObject setValue:[dict valueForKey:webKey] forKey:@"systemId"];
                if ([classObject respondsToSelector:NSSelectorFromString(@"dirty")]) // Object needs to load fault
                    [classObject setValue:@2 forKey:@"dirty"];
#if DEBUG
                else
                    NSLog(@"Warning: %@ is not faultable ('dirty' key missing)", NSStringFromClass([classObject class]));
#endif
            }
            
            [object setValue:classObject forKey:key];
        }
        // Special case for dates: Need to be converted from a string containing ISO8601
        else if ([object classOfPropertyNamed:key] == [NSDate class])
        {
            // NSLog(@"Adding %@ (Date) to %@ %@", key, NSStringFromClass([map classToMap]), [dict objectForKey:@"id"]);
            NSDate *date = [[[TSNRESTManager sharedManager] ISO8601Formatter] dateFromString:[dict objectForKey:webKey]]; // This method also supports epoch timestamps.
            [object setValue:date forKey:key];
        }
        // Assume NSString or NSNumber for everything else.
        else if ([dict valueForKey:webKey] != [NSNull null] && [[dict valueForKey:webKey] isKindOfClass:[object classOfPropertyNamed:key]])
        {
            //  NSLog(@"Adding %@ (String/Number) to %@ %@", key, NSStringFromClass([map classToMap]), [dict objectForKey:@"id"]);])
            [object setValue:[dict objectForKey:webKey] forKey:key];
        }
    }
    if (map.mappingBlock)
        map.mappingBlock(object, context, dict);
    
#if DEBUG
    // NSLog(@"Complete object: %@", object);
#endif
}

@end
