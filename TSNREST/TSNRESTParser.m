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

+ (BOOL)parseAndPersistDictionary:(NSDictionary *)dict withCompletion:(void (^)())completion forObject:(id)object
{
#if DEBUG
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
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
            
            if (object && [object valueForKey:@"systemId"] == nil && [map classToMap] == [object class] && jsonData.count == 1)
            {
                [object setValue:[[jsonData objectAtIndex:0] valueForKey:@"id"] forKey:@"systemId"];
                NSError *error = [[NSError alloc] init];
                [[object managedObjectContext] save:&error];
            }
            
            [self parseAndPersistArray:jsonData withObjectMap:map];
            
        }
        else
        {
#if DEBUG
            NSLog(@"No object map for %@", dictKey);
#endif
        }
    }
    
#if DEBUG
    NSLog(@"Parsing took %f", [NSDate timeIntervalSinceReferenceDate] - start);
#endif
    
    
    if (completion)
        completion();
    
    dispatch_async(dispatch_get_main_queue(), ^{
#if DEBUG
        NSLog(@"Notifying everyone that new data is here, Praise TFSM");
#endif
        [[NSNotificationCenter defaultCenter] postNotificationName:@"newData" object:nil];
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
    
    for (NSDictionary *dict in array)
    {
#if DEBUG
        /*
         Start the loop by logging what object we are adding.
         */
        NSLog(@"Adding %@ %@", NSStringFromClass([map classToMap]), [dict objectForKey:@"id"]);
#endif
        
        // Check if systemId exists
        NSNumber *systemId = [dict objectForKey:@"id"];
        
        
        
        // Check if existing object is saved locally
        id object = nil;
        id existingId = [existingSet member:systemId];
        if (existingId) // Object exists
        {
            NSLog(@"Found existing %@ %@", NSStringFromClass([map classToMap]), [dict objectForKey:@"id"]);
            NSUInteger index = [existingIds indexOfObjectIdenticalTo:existingId];
            object = [[existingObjects objectAtIndex:index] inContext:localContext];
        }
        
        
        
        // If there is no object, create one.
        if (!object)
        {
            NSLog(@"Created new %@: %@", NSStringFromClass([map classToMap]), [dict objectForKey:@"id"]);
            object = [[map classToMap] createInContext:localContext];
        }
        // If we have an object, and this mapping should ignore updates, keep calm and carry on.
        else if (map.shouldIgnoreUpdates && [object respondsToSelector:NSSelectorFromString(@"dirty")] && [[object valueForKey:@"dirty"] isEqualToNumber:@0])
        {
            NSLog(@"Object exists, and should be immutable. Ignore.");
            return;
        }
        
        
        
        if ([object respondsToSelector:NSSelectorFromString(@"updatedAt")])
        {
            NSDate *objectDate = [object valueForKey:@"updatedAt"];
            NSDate *webDate = [[[TSNRESTManager sharedManager] ISO8601Formatter] dateFromString:[dict objectForKey:[[map objectToWeb] valueForKey:@"updatedAt"]]];
            if (webDate && [objectDate isKindOfClass:[NSDate class]] && [objectDate isEqualToDate:webDate])
            {
                NSLog(@"Updated timestamp hasn't changed. Moving on.");
                continue;
            }
        }
        
        if ([object respondsToSelector:NSSelectorFromString(@"systemId")])
            [object setValue:[dict objectForKey:@"id"] forKey:@"systemId"];
        if ([object respondsToSelector:NSSelectorFromString(@"dirty")])
        {
            if ([[object valueForKey:@"dirty"] integerValue] == 1)
            {
                [(NSManagedObject *)object persist];
                continue;
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
                    [self parseAndPersistArray:[dict valueForKey:webKey] withObjectMap:oMap inContext:localContext];
                }
                else
                {
#if DEBUG
                    NSLog(@"Found no object map for %@", webKey);
#endif
                }
            }
            else if ([[object classOfPropertyNamed:key] isSubclassOfClass:[NSManagedObject class]] && [dict valueForKey:webKey] != [NSNull null])
            {
                // NSLog(@"Adding %@ (%@) to %@ %@", key, [object classOfPropertyNamed:key], NSStringFromClass([map classToMap]), [dict objectForKey:@"id"]);
                id classObject = nil;
                classObject = [[object classOfPropertyNamed:key] findFirstByAttribute:@"systemId" withValue:[dict valueForKey:webKey] inContext:localContext];
                
                if (!classObject) // Create a new, empty object and set system id
                {
#if DEBUG
                    NSLog(@"Created new %@ with id %@ and added it to %@ %@", [object classOfPropertyNamed:key], [dict valueForKey:webKey], NSStringFromClass([object class]), [object valueForKey:@"systemId"]);
#endif
                    classObject = [[object classOfPropertyNamed:key] createInContext:localContext];
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
            
            if (map.mappingBlock)
                map.mappingBlock(object, localContext, dict);
        }
        // NSLog(@"Complete object: %@", object);
    }
    
#if DEBUG
    NSLog(@"Parsing %i objects of type %@ took %f seconds", array.count, NSStringFromClass([map classToMap]), [NSDate timeIntervalSinceReferenceDate] - start);
#endif
}

@end
