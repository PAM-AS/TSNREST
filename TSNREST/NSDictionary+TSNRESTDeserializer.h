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

- (NSManagedObject *)mapToObject:(NSManagedObject *)object withMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)context optimize:(BOOL)optimize;

@end
