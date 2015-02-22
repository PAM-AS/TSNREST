//
//  NSArray+TSNRESTDeserializer.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import <Foundation/Foundation.h>
#import "TSNRESTManager.h"

@interface NSArray (TSNRESTDeserializer)

/**
 Converts all contained JSON objects to NSManagedObjects by using the specified object map, and saves them to the store.
 
 @param map The object map to use
 @param localContext The NSManagedObjectContext to use
 @param optimize Set whether to skip objects where the optimizableKey (set in TSNRESTManagerConfiguration) hasn't changed
 */
- (void)deserializeWithMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)localContext optimize:(BOOL)optimize;

@end
