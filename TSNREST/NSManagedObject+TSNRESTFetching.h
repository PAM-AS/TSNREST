//
//  NSManagedObject+TSNRESTFetching.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (TSNRESTFetching)

+ (NSManagedObject *)findOrCreateBySystemId:(NSNumber *)systemId inContext:(NSManagedObjectContext *)context;
+ (void)findOnServerById:(NSNumber *)systemId completion:(void(^)(NSManagedObject *object))completion;

@end
