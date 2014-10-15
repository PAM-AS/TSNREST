//
//  NSManagedObject+TSNRESTAdditions.h
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "TSNRESTManager.h"
#import "NSSet+TSNRESTAdditions.h"

@interface NSManagedObject (TSNRESTAdditions)

@property (nonatomic) BOOL inFlight;

- (id)get:(NSString *)propertyKey;

- (void)saveAndPersist;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock;
- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock optionalKeys:(NSArray *)optionalKeys;

- (void)deleteFromServer;
- (void)deleteFromServerWithCompletion:(void (^)(id object, BOOL success))completion;

- (BOOL)hasBeenDeleted;

- (void)faultIfNeeded;
- (void)faultIfNeededWithCompletion:(void (^)(id object, BOOL success))completion;
- (void)checkForDeletion:(void (^)(BOOL hasBeenDeleted))completion;
- (void)refresh;
- (void)refreshWithCompletion:(void (^)(id object, BOOL success))completion;

+ (NSArray *)propertyNames;
- (NSDictionary *)dictionaryRepresentation;
- (NSString *)JSONRepresentation;

+ (void)refresh;
+ (void)refreshWithCompletion:(void (^)())completion;

+ (void)findOnServerByAttribute:(NSString *)objectAttribute value:(NSString *)value completion:(void (^)(NSArray *results))completion;
+ (void)findOnServerByAttribute:(NSString *)objectAttribute pluralizedWebAttribute:(NSString *)pluralizedWebAttribute values:(NSArray *)values completion:(void (^)(NSArray *results))completion;

@end
