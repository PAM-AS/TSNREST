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
#import "NSManagedObject+TSNRESTSerializer.h"
#import "NSArray+TSNRESTDeserializer.h"
#import "NSDictionary+TSNRESTDeserializer.h"

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
#endif
    
    __block NSInteger objects = 0;
    
    [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
        for (NSString *dictKey in dict)
        {
            TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForServerPath:dictKey];
            if (map)
            {
                NSArray *jsonData = [dict objectForKey:dictKey];
                objects += jsonData.count;
                
                if (object && [object valueForKey:@"systemId"] == nil && [map classToMap] == [object class] && jsonData.count == 1)
                {
#if DEBUG
                    NSLog(@"First write to object (recently created), so setting ID for object %@", object);
#endif
                    id localObject = nil;
                    if (![localObject isDeleted])
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
                            [data mapToObject:localObject withMap:map inContext:localContext optimize:NO];
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
                else if ([object isDeleted]) {
                    NSLog(@"Object has recently been deleted, can't be updated.");
                }
#endif
                
                [jsonData deserializeWithMap:map inContext:localContext optimize:objects > 100];
            }
            else
            {
#if DEBUG
                NSLog(@"No object map found. Bailing out.");
#endif
            }
        }
        
#if DEBUG
        NSLog(@"Parsing %lu arrays (%li objects) took %f", (unsigned long)dict.count, (long)objects, [NSDate timeIntervalSinceReferenceDate] - start);
#endif
    } completion:^(BOOL contextDidSave, NSError *error) {
        [self doneWithCompletion:completion dict:dict];
    }];
    
    return YES;
}

+ (void)doneWithCompletion:(void (^)())completion dict:(NSDictionary *)dict
{
    NSLog(@"Done parsing");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Handing back torch to main thread");
        if (completion)
            completion();
        if ([[dict allKeys] count] > 0)
            [[NSNotificationCenter defaultCenter] postNotificationName:@"newData" object:[dict allKeys]];
#if DEBUG
        NSLog(@"Notifying everyone that new data is here, Praise TFSM");
#endif
    });
}

@end
