//
//  TSNRESTManager.h
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreData+MagicalRecord.h"
#import "TSNRESTObjectMap.h"
#import "NSManagedObject+TSNRESTAdditions.h"
#import "NSArray+TSNRESTAdditions.h"
#import "TSNRESTLogin.h"
#import "NSURL+TSNRESTAdditions.h"
#import "NJISO8601Formatter.h"
#import "NSManagedObject+TSNRESTDeletion.h"

@protocol TSNRESTManagerDelegate <NSObject>

@required
- (NSString *)authURL;

@optional
- (Class)userClass;
- (void (^)(id object, BOOL success))loginCompleteBlock;

@end

@interface TSNRESTManager : NSObject

@property (nonatomic, assign) id <TSNRESTManagerDelegate> delegate;

@property (nonatomic, strong) NJISO8601Formatter *ISO8601Formatter;

@property (atomic) BOOL isAuthenticating;
@property (nonatomic, assign) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSMutableDictionary *objectMaps;
@property (nonatomic, strong) NSMutableDictionary *customHeaders;

+ (id)sharedManager;

- (void)addRequestToLoading:(NSURLRequest *)request;
- (void)removeRequestFromLoading:(NSURLRequest *)request;
- (BOOL)isLoading;

- (NSURLSession *)URLSession;
- (void)reAuthenticate;

- (void)addObjectMap:(TSNRESTObjectMap *)objectMap;
- (TSNRESTObjectMap *)objectMapForClass:(Class)classToFind;
- (TSNRESTObjectMap *)objectMapForServerPath:(NSString *)path;
- (TSNRESTObjectMap *)objectMapForPushKey:(NSString *)path;
- (void)setGlobalHeader:(NSString *)header forKey:(NSString *)key;

- (void)deleteObjectFromServer:(id)object DEPRECATED_ATTRIBUTE;
- (void)deleteObjectFromServer:(id)object completion:(void (^)(id object, BOOL success))completion DEPRECATED_ATTRIBUTE;

// Common helpers for other TSNREST components
- (NSURLRequest *)requestForObject:(id)object DEPRECATED_ATTRIBUTE;
- (NSURLRequest *)requestForObject:(id)object optionalKeys:(NSArray *)optionalKeys DEPRECATED_ATTRIBUTE;

/*
 Run a request that will automatically attempt to reauthenticate if it receives a 401 status.
 The completion block will currently return unsuccessful on the first request if this happens.
 */
- (void)addRequestToAuthQueue:(NSDictionary *)request;
- (void)runAutoAuthenticatingRequest:(NSURLRequest *)request completion:(void (^)(BOOL success, BOOL newData, BOOL retrying))completion DEPRECATED_ATTRIBUTE;

- (void)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion DEPRECATED_ATTRIBUTE;
- (void)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion session:(NSURLSession *)session DEPRECATED_ATTRIBUTE;

- (void)flushQueuedRequests;
- (void)runQueuedRequests;
// If no request dict is supplied, function will not retry after a potential reauthentication (401)
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion DEPRECATED_ATTRIBUTE;
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion requestDict:(NSDictionary *)requestDict DEPRECATED_ATTRIBUTE;

- (NSDictionary *)dictionaryFromObject:(id)object withObjectMap:(TSNRESTObjectMap *)objectMap optionalKeys:(NSArray *)optionalKeys DEPRECATED_ATTRIBUTE;

- (void)resetDataStore DEPRECATED_ATTRIBUTE;

@end
