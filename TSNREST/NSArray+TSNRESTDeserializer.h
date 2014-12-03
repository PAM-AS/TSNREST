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

- (void)deserializeWithMap:(TSNRESTObjectMap *)map inContext:(NSManagedObjectContext *)localContext optimize:(BOOL)optimize;

@end
