//
//  NSManagedObject+TSNRESTAdditions.h
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#define MR_SHORTHAND 1

#import <CoreData/CoreData.h>
#import "CoreData+MagicalRecord.h"
#import "TSNRESTManager.h"
#import "NSSet+TSNRESTAdditions.h"

@interface NSManagedObject (TSNRESTAdditions)

- (void)persist;
- (void)persistWithCompletion:(void (^)(id object, BOOL success))completion;
- (void)persistWithCompletion:(void (^)(id object, BOOL success))completion session:(NSURLSession *)session;

- (void)deleteFromServer;
- (void)deleteFromServerWithCompletion:(void (^)(id object, BOOL success))completion;

- (void)faultIfNeeded;
- (void)faultIfNeededWithCompletion:(void (^)(id object, BOOL success))completion;
- (void)refresh;
- (void)refreshWithCompletion:(void (^)(id object, BOOL success))completion;

- (NSString *)JSONRepresentation;

+ (void)refresh;
+ (void)refreshWithCompletion:(void (^)())completion;

+ (void)findOnServerByAttribute:(NSString *)objectAttribute value:(NSString *)value completion:(void (^)(NSArray *results))completion;
+ (void)findOnServerByAttribute:(NSString *)objectAttribute pluralizedWebAttribute:(NSString *)pluralizedWebAttribute values:(NSArray *)values completion:(void (^)(NSArray *results))completion;

@end
