//
//  NSManagedObject+TSNRESTDeletion.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 02.12.14.
//
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (TSNRESTDeletion)

- (void)deleteFromServer;
- (void)deleteFromServerWithCompletion:(void (^)(id object, BOOL success))completion;

@end
