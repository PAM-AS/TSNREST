//
//  TSNRESTManager.m
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import "TSNRESTManager.h"
#import "TSNRESTParser.h"
#import "NSObject+PropertyClass.h"
#import "NSDate+SAMAdditions.h"
#import "NSString+TSNRESTCasing.h"
#import "NSManagedObject+TSNRESTSerializer.h"
#import "NSURLRequest+TSNRESTConveniences.h"
#import "NSURLSessionDataTask+TSNRESTDataTask.h"
#import "NSManagedObject+TSNRESTDeletion.h"

@interface TSNRESTManager ()

@property (nonatomic, strong) TSNRESTPoller *poller; // Need a setter internally.

@property (nonatomic, strong) NSMutableSet *requestQueue;
@property (nonatomic, strong) NSMutableSet *currentRequests;
@property (nonatomic, strong) NSMutableDictionary *customHeaders;
@property (nonatomic, strong) NSMutableDictionary *objectMaps;

@end

@implementation TSNRESTManager

+ (TSNRESTManager *)sharedManager
{
    // structure used to test whether the block has completed or not
    static dispatch_once_t p = 0;
    
    // initialize sharedObject as nil (first call only)
    __strong static id _sharedObject = nil;
    
    // executes a block object once and only once for the lifetime of an application
    dispatch_once(&p, ^{
        _sharedObject = [[self alloc] init];
        [(TSNRESTManager *)_sharedObject setRequestQueue:[[NSMutableSet alloc] init]];
        [(TSNRESTManager *)_sharedObject setCurrentRequests:[[NSMutableSet alloc] init]];
        [[NSNotificationCenter defaultCenter] addObserver:_sharedObject selector:@selector(loginSucceeded) name:@"LoginSucceeded" object:nil];
    });
    
    // returns the same object each time
    return _sharedObject;
}

- (void)addRequestToLoading:(NSURLRequest *)request {
    if (!request)
        return;
    @synchronized(self.currentRequests) {
        if (self.currentRequests.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"startLoadingAnimation" object:nil];
            });
        }
        [self.currentRequests addObject:request];
    }
}

- (void)removeRequestFromLoading:(NSURLRequest *)request {
    if (!request)
        return;
    @synchronized(self.currentRequests) {
        [self.currentRequests removeObject:request];
        if (self.currentRequests.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"stopLoadingAnimation" object:nil];
            });
        }
    }
}

#pragma mark - Getters & setters
- (BOOL)isLoading
{
    return (self.currentRequests.count > 0);
}

- (TSNRESTManagerConfiguration *)configuration {
    if (!_configuration)
        _configuration = [[TSNRESTManagerConfiguration alloc] init];
    return _configuration;
}

- (TSNRESTSession *)session {
    if (!_session)
        _session = [[TSNRESTSession alloc] init];
    return _session;
}

- (NJISO8601Formatter *)ISO8601Formatter
{
    if (!_ISO8601Formatter)
        _ISO8601Formatter = [[NJISO8601Formatter alloc] init];
    return _ISO8601Formatter;
}

- (TSNRESTPoller *)poller {
    if (!_poller)
        _poller = [[TSNRESTPoller alloc] init];
    return _poller;
}

- (NSDictionary *)customHeaders {
    return [NSDictionary dictionaryWithDictionary:_customHeaders];
}

#pragma mark - Session
- (NSURLSession *)URLSession {
    return [NSURLSession sharedSession]; // We currently use the shared session, but this is a convenient override point.
}

#pragma mark - Functions
- (void)addObjectMap:(TSNRESTObjectMap *)objectMap
{
    if (!self.objectMaps)
        self.objectMaps = [[NSMutableDictionary alloc] init];
    [self.objectMaps setObject:objectMap forKey:NSStringFromClass(objectMap.classToMap)];
}

- (void)setGlobalHeader:(NSString *)header forKey:(NSString *)key
{
    if (!_customHeaders)
        _customHeaders = [[NSMutableDictionary alloc] init];
    if (header)
        [_customHeaders setObject:header forKey:key];
    else
        [_customHeaders removeObjectForKey:key];
}

- (void)setGlobalHeaderFromSettingsKey:(NSString *)settingsKey forKey:(NSString *)key {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:settingsKey]) {
        [self setGlobalHeader:[NSString stringWithFormat:@"%@", [[NSUserDefaults standardUserDefaults] objectForKey:settingsKey]] forKey:key];
    }
    else {
        [self setGlobalHeader:nil forKey:key];
    }
}

- (TSNRESTObjectMap *)objectMapForClass:(Class)classToFind
{
    NSLog(@"Finding object map for class %@", NSStringFromClass(classToFind));
    return [self.objectMaps objectForKey:NSStringFromClass(classToFind)];
}

- (TSNRESTObjectMap *)objectMapForServerPath:(NSString *)path
{
    for (TSNRESTObjectMap *map in self.objectMaps.allValues)
    {
        if ([map.serverPath isEqualToString:path])
            return map;
    }
    
    return nil;
}

- (TSNRESTObjectMap *)objectMapForPushKey:(NSString *)path
{
    for (TSNRESTObjectMap *map in self.objectMaps.allValues)
    {
        if ([map.pushKey isEqualToString:path])
            return map;
    }
    
    return nil;
}

#pragma mark - Network helpers
- (void)addRequestToAuthQueue:(NSDictionary *)request
{
    @synchronized(self.requestQueue) {
        [self.requestQueue addObject:request];
    }
}

- (void)flushQueuedRequests
{
    @synchronized(self.requestQueue) {
        [self.requestQueue removeAllObjects];
    }
}

- (void)loginSucceeded
{
    self.isAuthenticating = NO;
    [self runQueuedRequests];
}

- (void)runQueuedRequests
{
    if (self.isAuthenticating)
    {
#if DEBUG
        NSLog(@"Can't run queued requests, still not done authenticating.");
#endif
        return;
    }
    
    NSArray *requestQueue = nil;

    @synchronized(self.requestQueue)
    {
#if DEBUG
        NSLog(@"Running %lu requests from queue", (unsigned long)self.requestQueue.count);
#endif
    
        requestQueue = [self.requestQueue allObjects];
    }
    
    for (NSDictionary *dictionary in requestQueue)
    {
        if ([[dictionary objectForKey:@"request"] isKindOfClass:[NSMutableURLRequest class]] && [[dictionary objectForKey:@"attempt"] integerValue] <= self.configuration.retryLimit.integerValue)
        {   
            NSMutableURLRequest *request = [dictionary objectForKey:@"request"];
            
            [request setAllHTTPHeaderFields:self.customHeaders];
            
            // Legacy completion block support
            if ([dictionary objectForKey:@"completion"]) {
                void (^completionBlock)(NSData *, NSURLResponse *, NSError *) = [dictionary objectForKey:@"completion"];
                [dictionary setValue:^(NSData *data, NSURLResponse *response, NSError *error){
                    completionBlock(data, response, error);
                } forKey:@"finallyBlock"];
            }
            
            
            NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:[dictionary objectForKey:@"successBlock"] failure:[dictionary objectForKey:@"failureBlock"] finally:[dictionary objectForKey:@"finallyBlock"] parseResult:[[dictionary objectForKey:@"parseResult"] boolValue] attempt:[dictionary objectForKey:@"attempt"]];
            [task resume];
        }
    }
    [self flushQueuedRequests];
}

#pragma mark - helpers
- (void)resetDataStore
{
    [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
        NSLog(@"Starting reset");
        for (NSEntityDescription *entity in [[NSManagedObjectModel MR_defaultManagedObjectModel] entities])
        {
            id thisClass = NSClassFromString(entity.name);
            if ([thisClass respondsToSelector:NSSelectorFromString(@"truncateAllInContext:")])
                [thisClass MR_truncateAllInContext:localContext];
        }
    } completion:^(BOOL success, NSError *error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"updateBadges" object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"dataReset" object:nil];
    }];
}

@end
