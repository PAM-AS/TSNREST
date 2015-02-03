//
//  NSArray+TSNRESTDeserializer.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import "NSArray+TSNRESTDeserializer.h"
#import "TSNRESTParser.h"
#import "NSDictionary+TSNRESTDeserializer.h"

@implementation NSArray (TSNRESTDeserializer)

- (void)deserializeWithMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)localContext optimize:(BOOL)optimize {
#if DEBUG
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
#endif
    
    NSArray *existingObjects = [[map classToMap] MR_findAllInContext:localContext];
    
    NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
    NSArray *existingIds = [existingObjects valueForKey:idKey];
    NSSet *newSet = [NSSet setWithArray:[self valueForKey:@"id"]?:@[]];
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
            NSLog(@"No objects of type %@ has been updated. Skipping %lu objects.", NSStringFromClass([map classToMap]), (unsigned long)self.count);
#endif
            return;
        }
    }
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:idKey ascending:YES];
    NSEnumerator *existingEnumerator = [[existingObjects sortedArrayUsingDescriptors:@[sortDescriptor]] objectEnumerator];
    
    sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES];
    NSArray *sortedArray = [self sortedArrayUsingDescriptors:@[sortDescriptor]];
    NSEnumerator *newEnumerator = [sortedArray objectEnumerator];
    
    NSDictionary *jsonObject = [newEnumerator nextObject];
    id existingObject = [existingEnumerator nextObject];
    
    while (jsonObject) {
        
        // while (id != id)
        // nextObject
        while (existingObject && [[jsonObject objectForKey:@"id"] intValue] > [[existingObject valueForKey:idKey] intValue]) {
            existingObject = [existingEnumerator nextObject];
        }
        
        id object = nil;
        
#if DEBUG
        if (![[existingObject valueForKey:idKey] isEqualToNumber:[jsonObject objectForKey:@"id"]])
        {
            NSLog(@"Moment of creation (not update): Existing object class: %@ id? %@ new object id: %@", NSStringFromClass([existingObject class]), [existingObject valueForKey:idKey], [jsonObject objectForKey:@"id"]);
        }
#endif
        
        if (existingObject && [[existingObject valueForKey:idKey] integerValue] == [[jsonObject objectForKey:@"id"] integerValue])
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
                
                existingObject = [map.classToMap MR_findFirstByAttribute:idKey withValue:[jsonObject objectForKey:@"id"] inContext:localContext];
                
#if DEBUG
                NSLog(@"Found this in the store: %@ (%@)", existingObject, [existingObject valueForKey:idKey]);
#endif
                
                if (existingObject && [[existingObject valueForKey:idKey] integerValue] == [[jsonObject objectForKey:@"id"] integerValue])
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
                    [object setValue:[jsonObject objectForKey:@"id"] forKey:idKey];
                }
            }
        }
        
        @autoreleasepool {
            [jsonObject mapToObject:object withMap:map inContext:localContext optimize:optimize];
        }
        jsonObject = [newEnumerator nextObject];
    }
    
#if DEBUG
    NSLog(@"Parsing %lu objects of type %@ took %f seconds", (unsigned long)self.count, NSStringFromClass([map classToMap]), [NSDate timeIntervalSinceReferenceDate] - start);
#endif
}

@end
