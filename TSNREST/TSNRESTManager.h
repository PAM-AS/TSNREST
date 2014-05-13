//
//  TSNRESTManager.h
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSNRESTObjectMap.h"
#import "NSManagedObject+TSNRESTAdditions.h"
#import "NSArray+TSNRESTAdditions.h"
#import "TSNRESTLogin.h"
#import "NSURL+TSNRESTAdditions.h"

@protocol TSNRESTManagerDelegate <NSObject>

@required
- (NSString *)authURL;

@optional
- (Class)userClass;

@optional
- (void (^)(id object, BOOL success))loginCompleteBlock;

@end

@interface TSNRESTManager : NSObject

@property (nonatomic) id <TSNRESTManagerDelegate> delegate;

@property (atomic) BOOL isAuthenticating;
@property (nonatomic) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSMutableDictionary *objectMaps;
@property (nonatomic, strong) NSMutableDictionary *customHeaders;

+ (id)sharedManager;

- (void)startLoading:(NSString *)identifier;
- (void)endLoading:(NSString *)identifier;
- (BOOL)isLoading;

- (void)addObjectMap:(TSNRESTObjectMap *)objectMap;
- (TSNRESTObjectMap *)objectMapForClass:(Class)classToFind;
- (TSNRESTObjectMap *)objectMapForServerPath:(NSString *)path;
- (TSNRESTObjectMap *)objectMapForPushKey:(NSString *)path;
- (void)setGlobalHeader:(NSString *)header forKey:(NSString *)key;

- (void)deleteObjectFromServer:(id)object;
- (void)deleteObjectFromServer:(id)object completion:(void (^)(id object, BOOL success))completion;

// Common helpers for other TSNREST components
- (NSURLRequest *)requestForObject:(id)object;

/* 
 Run a request that will automatically attempt to reauthenticate if it receives a 401 status.
 The completion block will currently return unsuccessful on the first request if this happens.
 */
- (void)runAutoAuthenticatingRequest:(NSURLRequest *)request completion:(void (^)(BOOL success, BOOL newData))completion;

- (void)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion DEPRECATED_ATTRIBUTE;
- (void)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion session:(NSURLSession *)session DEPRECATED_ATTRIBUTE;

- (void)runQueuedRequests;
// If no request dict is supplied, function will not retry after a potential reauthentication (401)
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion;
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion requestDict:(NSDictionary *)requestDict;

- (NSDictionary *)dictionaryFromObject:(id)object withObjectMap:(TSNRESTObjectMap *)objectMap;

- (void)resetDataStore;

@end
