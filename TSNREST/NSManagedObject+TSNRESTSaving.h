//
//  NSManagedObject+TSNRESTSaving.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 22.11.14.
//
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (TSNRESTSaving)

- (void)saveAndPersist;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock optionalKeys:(NSArray *)optionalKeys;


@end
