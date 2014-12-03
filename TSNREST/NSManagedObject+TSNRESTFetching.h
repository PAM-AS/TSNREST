//
//  NSManagedObject+TSNRESTFetching.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (TSNRESTFetching)

+ (NSManagedObject *)findOrCreateBySystemId:(NSNumber *)systemid inContext:(NSManagedObjectContext *)context;

@end
