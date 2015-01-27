//
//  NSManagedObject+TSNRESTSaving.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 22.11.14.
//
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (TSNRESTSaving)

/*
 Saving objects to the server
 
 You can pick your level of callbacks from the methods below. They all call the same method behind the scenes.
 
 All callback blocks are always run on the main thread, and inputs the object on the main thread MOC.
 */

- (void)saveAndPersist;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock optionalKeys:(NSArray *)optionalKeys;


@end
