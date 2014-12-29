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
#import "TSNRESTPoller.h"
#import "TSNRESTManagerConfiguration.h"

@protocol TSNRESTManagerDelegate <NSObject>

@required
- (NSString *)authURL;

@optional
- (Class)userClass;
- (void (^)(id object, BOOL success))loginCompleteBlock;

@end

@interface TSNRESTManager : NSObject

@property (nonatomic, assign) id <TSNRESTManagerDelegate> delegate;

@property (nonatomic, strong) TSNRESTManagerConfiguration *configuration;
@property (nonatomic, strong) NJISO8601Formatter *ISO8601Formatter;
@property (nonatomic, strong, readonly) TSNRESTPoller *poller;

@property (atomic) BOOL isAuthenticating;

+ (TSNRESTManager *)sharedManager;

- (void)addRequestToLoading:(NSURLRequest *)request;
- (void)removeRequestFromLoading:(NSURLRequest *)request;

- (void)addSelfSavingObject:(NSManagedObject *)object;
- (void)removeSelfSavingObject:(NSManagedObject *)object;
- (BOOL)isLoading;

- (NSURLSession *)URLSession;
- (NSDictionary *)customHeaders;
- (void)reAuthenticate;

- (void)addObjectMap:(TSNRESTObjectMap *)objectMap;
- (TSNRESTObjectMap *)objectMapForClass:(Class)classToFind;
- (TSNRESTObjectMap *)objectMapForServerPath:(NSString *)path;
- (TSNRESTObjectMap *)objectMapForPushKey:(NSString *)path;

// Passing nil as header or a settingskey where no setting exists, will remove the header.
- (void)setGlobalHeader:(NSString *)header forKey:(NSString *)key;
- (void)setGlobalHeaderFromSettingsKey:(NSString *)settingsKey forKey:(NSString *)key;

/*
 Run a request that will automatically attempt to reauthenticate if it receives a 401 status.
 The completion block will currently return unsuccessful on the first request if this happens.
 */
- (void)addRequestToAuthQueue:(NSDictionary *)request;
- (void)runAutoAuthenticatingRequest:(NSURLRequest *)request completion:(void (^)(BOOL success, BOOL newData, BOOL retrying))completion DEPRECATED_ATTRIBUTE;

- (void)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion DEPRECATED_ATTRIBUTE;
- (void)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion session:(NSURLSession *)session DEPRECATED_ATTRIBUTE;

- (void)flushQueuedRequests;

// If no request dict is supplied, function will not retry after a potential reauthentication (401)
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion DEPRECATED_ATTRIBUTE;
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion requestDict:(NSDictionary *)requestDict DEPRECATED_ATTRIBUTE;

- (NSDictionary *)dictionaryFromObject:(id)object withObjectMap:(TSNRESTObjectMap *)objectMap optionalKeys:(NSArray *)optionalKeys DEPRECATED_ATTRIBUTE;

- (void)resetDataStore DEPRECATED_ATTRIBUTE;

@end
