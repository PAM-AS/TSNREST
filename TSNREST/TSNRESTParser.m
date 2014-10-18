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
    __block NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    __block NSInteger objects = 0;
#endif
    
    dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
        [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
            for (NSString *dictKey in dict)
            {
                TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForServerPath:dictKey];
                if (map)
                {
                    NSArray *jsonData = [dict objectForKey:dictKey];
#if DEBUG
                    objects += jsonData.count;
#endif
                    
                    if (object && [object valueForKey:@"systemId"] == nil && [map classToMap] == [object class] && jsonData.count == 1)
                    {
#if DEBUG
                        NSLog(@"First write to object (recently created), so setting ID for object %@", object);
#endif
                        id localObject = nil;
                        if (![localObject hasBeenDeleted])
                            localObject = [object MR_inContext:localContext];
                        id systemId = [[jsonData objectAtIndex:0] valueForKey:@"id"];
                        if (systemId)
                        {
                            id existingObject = [[localObject class] MR_findFirstByAttribute:@"systemId" withValue:systemId inContext:localContext];
                            
                            // Not quite sure why this catches things that the Core Data query above does not, but we need it to avoid bugs.
                            if (existingObject && localObject)
                            {
#if DEBUG
                                NSLog(@"Found existing object. Appending it's data to our object, then deleting it (%@).", [existingObject valueForKey:@"systemId"]);
#endif
                                NSDictionary *data = [(NSManagedObject *)existingObject dictionaryRepresentation];
                                [self mapDict:data toObject:localObject withMap:map inContext:localContext];
                                [existingObject MR_deleteEntity];
                            }
                            else if (localObject)
                            {
                                NSLog(@"No existing object. Setting id (%@) to input object", systemId);
                                [[localObject MR_inContext:localContext] setValue:systemId forKey:@"systemId"];
                            }
                        }
                        else
                        {
                            NSLog(@"No existing object, and no id. Skipping any further action.");
                        }
                        NSLog(@"Done setting ID: %@", localObject);
                    }
                    
#if DEBUG
                    else if (!object) {
                        NSLog(@"Got no object as input, skipping setting of id");
                    }
                    else if ([object valueForKey:@"systemId"] != nil) {
                        NSLog(@"Input object already has ID %@, continuing to update", [object valueForKey:@"systemId"]);
                    }
                    else if ([map classToMap] != [object class]) {
                        NSLog(@"Got wrong objectmap (%@ != %@), skipping setting id", NSStringFromClass([map classToMap]), NSStringFromClass([object class]));
                    }
                    else if (jsonData.count != 1) {
                        NSLog(@"Got more or less than 1 object in return. Continuing to parsing. (got %li)", (unsigned long)jsonData.count);
                    }
                    else if ([object hasBeenDeleted]) {
                        NSLog(@"Object has recently been deleted, can't be updated.");
                    }
#endif
                    
                    [self parseAndPersistArray:jsonData withObjectMap:map context:localContext];
                }
                else
                {
#if DEBUG
                    NSLog(@"No object map found. Bailing out.");
#endif
                }
            }
            
#if DEBUG
            NSLog(@"Parsing %lu arrays (%i objects) took %f", (unsigned long)dict.count, objects, [NSDate timeIntervalSinceReferenceDate] - start);
#endif
        } completion:^(BOOL contextDidSave, NSError *error) {
            [self doneWithCompletion:completion dict:dict];
        }];
    });
    
    return YES;
}

+ (void)doneWithCompletion:(void (^)())completion dict:(NSDictionary *)dict
{
    NSLog(@"Done parsing");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Handing back torch to main thread");
        if (completion)
            completion();
        [[NSNotificationCenter defaultCenter] postNotificationName:@"newData" object:[dict allKeys]];
#if DEBUG
        NSLog(@"Notifying everyone that new data is here, Praise TFSM");
#endif
    });
}

+ (BOOL)parseAndPersistArray:(NSArray *)array withObjectMap:(TSNRESTObjectMap *)map context:(NSManagedObjectContext *)localContext
{
    NSLog(@"Starting Magic block in parseAndPersistArray for map %@", NSStringFromClass([map classToMap]));
    [self parseAndPersistArray:array withObjectMap:map inContext:localContext];
    NSLog(@"Stopping Magic block in parseAndPersistArray for map %@", NSStringFromClass([map classToMap]));
    return YES;
}

+ (void)parseAndPersistArray:(NSArray *)array withObjectMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)localContext
{
    
#if DEBUG
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
#endif
    
    // Core Data is strange. https://github.com/magicalpanda/MagicalRecord/issues/25
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];

    NSArray *existingObjects = [[map classToMap] MR_findAllInContext:localContext];
    
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
            NSLog(@"No objects of type %@ has been updated. Skipping %lu objects.", NSStringFromClass([map classToMap]), (unsigned long)array.count);
#endif
            return;
        }
    }
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"systemId" ascending:YES];
    NSEnumerator *existingEnumerator = [[existingObjects sortedArrayUsingDescriptors:@[sortDescriptor]] objectEnumerator];
    
    sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES];
    NSArray *sortedArray = [array sortedArrayUsingDescriptors:@[sortDescriptor]];
    NSEnumerator *newEnumerator = [sortedArray objectEnumerator];
    
    NSDictionary *jsonObject = [newEnumerator nextObject];
    id existingObject = [existingEnumerator nextObject];
    
    while (jsonObject) {
        
        // while (id != id)
            // nextObject
        while (existingObject && [[jsonObject objectForKey:@"id"] intValue] > [[existingObject valueForKey:@"systemId"] intValue]) {
            existingObject = [existingEnumerator nextObject];
        }
        
        id object = nil;
        
#if DEBUG
        if (![[existingObject valueForKey:@"systemId"] isEqualToNumber:[jsonObject objectForKey:@"id"]])
        {
            NSLog(@"Moment of creation (not update): Existing object class: %@ id? %@ new object id: %@", NSStringFromClass([existingObject class]), [existingObject valueForKey:@"systemId"], [jsonObject objectForKey:@"id"]);
        }
#endif
        
        if (existingObject && [[existingObject valueForKey:@"systemId"] integerValue] == [[jsonObject objectForKey:@"id"] integerValue])
        {
            object = existingObject;
        }
        else
        {
#if DEBUG
            NSLog(@"Don't give up, ask the store for this ID in particular");
#endif
            // Try to fetch from store, one last time
            @synchronized([TSNRESTParser class])
            {
                // Core Data is strange. https://github.com/magicalpanda/MagicalRecord/issues/25
                [localContext MR_saveOnlySelfAndWait];
                
                existingObject = [map.classToMap MR_findFirstByAttribute:@"systemId" withValue:[jsonObject objectForKey:@"id"] inContext:localContext];
                
#if DEBUG
                NSLog(@"Found this in the store: %@ (%@)", existingObject, [existingObject valueForKey:@"systemId"]);
#endif
                
                if (existingObject && [[existingObject valueForKey:@"systemId"] integerValue] == [[jsonObject objectForKey:@"id"] integerValue])
                {
#if DEBUG
                    NSLog(@"Payoff! Object really did exist.");
#endif
                    object = existingObject;
                }
                else
                {
#if DEBUG
                    NSLog(@"Nope. No object. Quite sure.");
#endif
                    object = [[map classToMap] MR_createInContext:localContext];
                    [object setValue:[jsonObject objectForKey:@"id"] forKey:@"systemId"];
                }
            }
        }
        
        [TSNRESTParser mapDict:jsonObject toObject:object withMap:map inContext:localContext];
        
        jsonObject = [newEnumerator nextObject];
    }
    
#if DEBUG
    NSLog(@"Parsing %lu objects of type %@ took %f seconds", (unsigned long)array.count, NSStringFromClass([map classToMap]), [NSDate timeIntervalSinceReferenceDate] - start);
#endif
}

+ (void)mapDict:(NSDictionary *)dict toObject:(id)globalobject withMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)context
{
    id object = [globalobject MR_inContext:context];
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
            NSLog(@"Skipping object that hasn't been updated since %@", webDate);
            return;
        }
    }
    
    // Duplicate avoidance (only works if server actually returns the uuid)
    if ([object respondsToSelector:NSSelectorFromString(@"uuid")] && [dict objectForKey:@"uuid"] && ![[object valueForKey:@"uuid"] isEqualToString:[dict objectForKey:@"uuid"]])
    {
        NSLog(@"Skipping because of matching UUIDs %@", [dict objectForKey:@"uuid"]);
        return;
    }
    
    
    if ([object respondsToSelector:NSSelectorFromString(@"systemId")])
        [object setValue:[dict objectForKey:@"id"] forKey:@"systemId"];
    if ([object respondsToSelector:NSSelectorFromString(@"dirty")])
    {
        if ([[object valueForKey:@"dirty"] integerValue] == 1)
        {
            [(NSManagedObject *)object saveAndPersist];
            NSLog(@"Object was dirty, attempting to persist it.");
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
            classObject = [[object classOfPropertyNamed:key]MR_findFirstByAttribute:@"systemId" withValue:[dict valueForKey:webKey] inContext:context];
            
            if (!classObject) // Create a new, empty object and set system id
            {
#if DEBUG
                NSLog(@"Created new %@ with id %@ and added it to %@ %@", [object classOfPropertyNamed:key], [dict valueForKey:webKey], NSStringFromClass([object class]), [object valueForKey:@"systemId"]);
#endif
                classObject = [[object classOfPropertyNamed:key] MR_createEntityInContext:context];
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
    if (map.mappingBlock && object)
        map.mappingBlock(object, context, dict);
    
#if DEBUG
    // NSLog(@"Complete object: %@", object);
#endif
}

@end
