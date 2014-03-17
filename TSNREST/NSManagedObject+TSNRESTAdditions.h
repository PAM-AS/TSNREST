//
//  NSManagedObject+TSNRESTAdditions.h
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "TSNRESTManager.h"

@interface NSManagedObject (TSNRESTAdditions)

- (void)persist;
- (void)persistWithCompletion:(void (^)(id object, BOOL success))completion;
- (void)persistWithCompletion:(void (^)(id object, BOOL success))completion session:(NSURLSession *)session;

- (void)deleteFromServer;

- (void)faultIfNeeded;
- (void)refresh;

+ (void)refresh;
+ (void)refreshWithCompletion:(void (^)())completion;

+ (void)findOnServerByAttribute:(NSString *)objectAttribute value:(NSString *)value completion:(void (^)(NSArray *results))completion;

@end
