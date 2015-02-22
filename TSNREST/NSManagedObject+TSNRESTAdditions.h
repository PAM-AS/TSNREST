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
#import "NSManagedObject+TSNRESTSaving.h"

@interface NSManagedObject (TSNRESTAdditions)

@property (nonatomic) BOOL inFlight;

//- (id)get:(NSString *)propertyKey;

/**
 Check if we need to load this from the server, and load if we do.
 
 @param completion an optional completion block
 */
- (void)faultIfNeeded;
- (void)faultIfNeededWithCompletion:(void (^)(id object, BOOL success))completion;

/**
 Check if object is present on the server or not. If the server responds with 404, the object is deleted locally.
 
 @param completion An optional completion block
 */
- (void)checkForDeletion:(void (^)(BOOL hasBeenDeleted))completion;

/**
 Reload the object from the server, regerdless of what state it is in
 
 @param queryParams Optional query parameters, which will expand @{@"key":@"value",@"key2",@"value2"} to ?key=value,key2=value2 and append it to the url.
 @param completion An optional completion block
 */
- (void)refresh;
- (void)refreshWithCompletion:(void (^)(id object, BOOL success))completion;
- (void)refreshWithQueryParams:(NSDictionary *)queryParameters completion:(void (^)(id object, BOOL success))completion;

/**
 Returns the property names of the MO
 
 @return array of property names
 */
+ (NSArray *)propertyNames;

/**
 Refreshes the whole class.
 
 Uses any global query param set at the object map
 
 @param completion An optional completion block
 */
+ (void)refresh;
+ (void)refreshWithCompletion:(void (^)())completion;

/**
 Find something on the server by a specific attribute. The attribute can be a related object or a value.
 
 @param objectAttribute The key you search for (will be converted to web_key automatically)
 @param value The value you search for. Can be an NSNumber, NSString or NSManagedObject
 @param queryParameters Optional query parameters, which will expand @{@"key":@"value",@"key2",@"value2"} to ?key=value,key2=value2 and append it to the url.
 @param completion An optional completion block. Contains an array of found NSManagedObjects.
 */
+ (void)findOnServerByAttribute:(NSString *)objectAttribute value:(id)value completion:(void (^)(NSArray *results))completion;
+ (void)findOnServerByAttribute:(NSString *)objectAttribute value:(id)value queryParameters:(NSDictionary *)queryParameters completion:(void (^)(NSArray *results))completion;

+ (void)findOnServerByAttribute:(NSString *)objectAttribute pluralizedWebAttribute:(NSString *)pluralizedWebAttribute values:(NSArray *)values completion:(void (^)(NSArray *results))completion __attribute__((deprecated("This method has been deprecated. Please use findOnServerByAttribute:objectAttribute:value:queryParameters:completion: instead.")));

@end
