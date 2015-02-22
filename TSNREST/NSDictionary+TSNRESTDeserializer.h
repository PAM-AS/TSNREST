//
//  NSDictionary+TSNRESTDeserializer.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import <Foundation/Foundation.h>
#import "TSNRESTManager.h"

@interface NSDictionary (TSNRESTDeserializer)

// + (void)mapDict:(NSDictionary *)dict toObject:(id)globalobject withMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)context optimize:(BOOL)optimize

/**
 map this dictionary to a specified NSManagedObject with a specified objectMap.
 
 @param object The NSManagedObject to map this dictionary into
 @param map The objectMap to use
 @param context The context to use
 @param optimize Set whether to skip this object if the optimizableKey (set in TSNRESTManagerConfiguration) hasn't changed
 @returns The updated object
 */
- (NSManagedObject *)mapToObject:(NSManagedObject *)object withMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)context optimize:(BOOL)optimize;

@end
