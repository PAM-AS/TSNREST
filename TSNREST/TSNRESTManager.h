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
#import "NSURL+TSNRESTAdditions.h"
#import "NJISO8601Formatter.h"
#import "NSManagedObject+TSNRESTDeletion.h"
#import "TSNRESTPoller.h"
#import "TSNRESTManagerConfiguration.h"
#import "TSNRESTSession.h"


@interface TSNRESTManager : NSObject

@property (nonatomic, strong) TSNRESTManagerConfiguration *configuration;
@property (nonatomic, strong) TSNRESTSession *session;
@property (nonatomic, strong) NJISO8601Formatter *ISO8601Formatter;
@property (nonatomic, strong, readonly) TSNRESTPoller *poller;

@property (atomic) BOOL isAuthenticating;

+ (TSNRESTManager *)sharedManager;

- (void)addRequestToLoading:(NSURLRequest *)request;
- (void)removeRequestFromLoading:(NSURLRequest *)request;

- (BOOL)isLoading;

- (NSURLSession *)URLSession;
- (NSDictionary *)customHeaders;

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
- (void)flushQueuedRequests;

- (void)resetDataStore;

@end
