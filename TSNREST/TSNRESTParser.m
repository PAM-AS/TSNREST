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

+ (void)parseAndPersistDictionary:(NSDictionary *)dict
{
    [self parseAndPersistDictionary:dict withCompletion:nil];
}

+ (void)parseAndPersistDictionary:(NSDictionary *)dict withCompletion:(void (^)())completion
{
    [self parseAndPersistDictionary:dict withCompletion:completion forObject:nil];
}

+ (void)parseAndPersistDictionary:(NSDictionary *)dict withCompletion:(void (^)())completion forObject:(id)object
{
#if DEBUG
    __block NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
#endif

    __block NSInteger objects = 0;
    
    [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        /*
         Strategy for not having to delete temporary objects: Always parse objects of type self first, and create the object that way.
         */
        
        NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
        if (object && ![object isDeleted] && [object valueForKey:idKey] == nil) {
            for (NSString *dictKey in dict)
            {
                TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForServerPath:dictKey];
                if (map && [map classToMap] == [object class]) {
                    NSArray *jsonData = [dict objectForKey:dictKey];
                    if (jsonData.count == 1) {
                        NSNumber *systemId = [[jsonData objectAtIndex:0] valueForKey:@"id"];
                        if (systemId) {
                            NSManagedObject *localObject = [object MR_inContext:localContext];
                            [localObject setValue:systemId forKey:idKey];
                            [localContext MR_saveOnlySelfAndWait];
                            [[object managedObjectContext] refreshObject:object mergeChanges:NO];
#if DEBUG
                            NSLog(@"Set id %@ to newly created object of class %@", [object valueForKey:idKey], NSStringFromClass([object class]));
#endif
                        }
#if DEBUG
                        else {
                            NSLog(@"Returned object didn't have a valid ID, skipping updating the object.");
                        }
#endif
                    }
#if DEBUG
                    else {
                        NSLog(@"Got more than one object of the type we saved Can't know which, skipping updating saved object.");
                    }
#endif
                }
            }
        }
#if DEBUG
        else {
            NSLog(@"No valid object to update, proceeding to parse as usual.");
        }
#endif
        
        
        for (NSString *dictKey in dict)
        {
            TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForServerPath:dictKey];
            if (map)
            {
                NSArray *jsonData = [dict objectForKey:dictKey];
                objects += jsonData.count;
                [jsonData deserializeWithMap:map inContext:localContext optimize:objects > 100];
            }
#if DEBUG
            else
            {
                NSLog(@"No object map found for %@. Bailing out.", dictKey);
            }
#endif
        }
        
#if DEBUG
        NSLog(@"Parsing %lu arrays (%li objects) took %f", (unsigned long)dict.count, (long)objects, [NSDate timeIntervalSinceReferenceDate] - start);
#endif
    }];
    [self doneWithCompletion:completion dict:dict];
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
