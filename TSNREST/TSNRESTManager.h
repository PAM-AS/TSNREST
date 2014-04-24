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
- (Class)userClass;
- (NSString *)authURL;

@optional
- (void (^)(id object, BOOL success))loginCompleteBlock;

@end

@interface TSNRESTManager : NSObject

@property (nonatomic) id <TSNRESTManagerDelegate> delegate;

@property (nonatomic) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSMutableDictionary *objectMaps;
@property (nonatomic, strong) NSMutableDictionary *customHeaders;

+ (id)sharedManager;

- (void)startLoading;
- (void)endLoading;

- (void)addObjectMap:(TSNRESTObjectMap *)objectMap;
- (TSNRESTObjectMap *)objectMapForClass:(Class)classToFind;
- (TSNRESTObjectMap *)objectMapForServerPath:(NSString *)path;
- (TSNRESTObjectMap *)objectMapForPushKey:(NSString *)path;
- (void)setGlobalHeader:(NSString *)header forKey:(NSString *)key;

- (void)deleteObjectFromServer:(id)object;
- (void)deleteObjectFromServer:(id)object completion:(void (^)(id object, BOOL success))completion;

// Common helpers for other TSNREST components
- (NSURLRequest *)requestForObject:(id)object;
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion;

- (NSDictionary *)dictionaryFromObject:(id)object withObjectMap:(TSNRESTObjectMap *)objectMap;

- (void)resetDataStore;

@end
