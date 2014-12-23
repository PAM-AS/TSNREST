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
@property (nonatomic, strong) NSMutableArray *selfSavingObjects;
@property (nonatomic, strong) NSMutableDictionary *customHeaders;

@end

@implementation TSNRESTManager

+ (id)sharedManager
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
        [(TSNRESTManager *)_sharedObject setSelfSavingObjects:[[NSMutableArray alloc] init]];
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

- (void)addSelfSavingObject:(NSManagedObject *)object {
    if (!object)
        return;
    @synchronized(self.selfSavingObjects) {
        [self.selfSavingObjects addObject:object];
    }
}

- (void)removeSelfSavingObject:(NSManagedObject *)object {
    if (!object)
        return;
    @synchronized(self.selfSavingObjects) {
        [self.selfSavingObjects removeObject:object];
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

- (void)setBaseURL:(NSString *)baseURL {
    [self.configuration setBaseURL:[NSURL URLWithString:baseURL]];
}

- (NSString *)baseURL {
    return self.configuration.baseURL.absoluteString;
}

- (NSDictionary *)customHeaders {
    return [NSDictionary dictionaryWithDictionary:_customHeaders];
}

#pragma mark - Session
- (NSURLSession *)URLSession {
    return [NSURLSession sharedSession]; // We currently use the shared session, but this is a convenient override point.
}

- (void)reAuthenticate {
    [TSNRESTLogin loginWithDefaultRefreshTokenAndUserClass:[self.delegate userClass] url:[self.delegate authURL]];
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
    [_customHeaders setObject:header forKey:key];
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


#pragma mark - Deletion
- (void)deleteObjectFromServer:(id)object
{
    [self deleteObjectFromServer:object completion:nil];
}

- (void)deleteObjectFromServer:(id)object completion:(void (^)(id object, BOOL success))completion
{
    [object deleteFromServerWithCompletion:completion];
}

#pragma mark - Network helpers
- (void)addRequestToAuthQueue:(NSDictionary *)request
{
    @synchronized(self.requestQueue) {
        [self.requestQueue addObject:request];
    }
}

- (void)runAutoAuthenticatingRequest:(NSURLRequest *)request completion:(void (^)(BOOL success, BOOL newData, BOOL retrying))completion
{
    /*
     Holy block, batman
     
     Weak reference copy of a strong reference block to avoid retain issues.
     
     http://stackoverflow.com/questions/18061750/recursive-block-gets-deallocated-too-early
     */
    
    __weak __block void (^weakRequestCompletion)(NSData *, NSURLResponse *, NSError *);
    __block void (^requestCompletion)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        __block void (^requestCompletion)(NSData *, NSURLResponse *, NSError *) = weakRequestCompletion;
        NSLog(@"Got response for autoauthingrequest: %@", request.URL.absoluteString);
        if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] > 204)
        {
            [self handleResponse:response withData:data error:error object:nil completion:^(id object, BOOL success) {
                if (completion)
                {
                    if ([(NSHTTPURLResponse *)response statusCode] != 401) // 401 will be picked up and retried
                        completion(success, NO, NO);
                    else
                        completion(success, NO, YES);
                }
            } requestDict:@{@"request":request, @"completion":requestCompletion}];
        }
        else
        {
            [self handleResponse:response withData:data error:error object:nil completion:^(id object, BOOL success) {
                if (completion)
                    completion(success, YES, NO);
            } requestDict:@{@"request":request, @"completion":requestCompletion}];
        }
    };
    
    weakRequestCompletion = requestCompletion;
    [self dataTaskWithRequest:request completionHandler:requestCompletion];
}

- (void)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion
{
    [self dataTaskWithRequest:request completionHandler:completion session:nil];
}

- (void)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion session:(NSURLSession *)session
{
    NSLog(@"Requesting datatask for request %@", request.URL.absoluteString);
    @synchronized([TSNRESTManager class]) {
        if (self.isAuthenticating)
        {
            NSDictionary *dictionary = nil;
            if (session)
                dictionary = @{@"request":request,@"completion":completion,@"session":session};
            else
                dictionary = @{@"request":request,@"completion":completion};
            @synchronized(self.requestQueue) {
                [self.requestQueue addObject:dictionary];
            }
            
            NSLog(@"Authentication is in progress. Datatask added to queue: %@", request.URL.absoluteString);
            
            return;
        }
    }
    
    NSURLSessionDataTask *task = nil;
    if (!session)
        task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completion];
    else
        task = [session dataTaskWithRequest:request completionHandler:completion];
    
    NSLog(@"Running datatask for request %@ (%@)", request.URL.absoluteString, task);
    
    [task resume];
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
        if ([[dictionary objectForKey:@"request"] isKindOfClass:[NSMutableURLRequest class]])
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
            
            
            NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:[dictionary objectForKey:@"successBlock"] failure:[dictionary objectForKey:@"failureBlock"] finally:[dictionary objectForKey:@"finallyBlock"]];
            [task resume];
        }
    }
}

#pragma mark - helpers
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion
{
    [self handleResponse:response withData:data error:error object:object completion:completion requestDict:nil];
}

- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion requestDict:(NSDictionary *)requestDict
{
    NSDictionary *responseDict = nil;
    if (data)
        responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    else
    {
        if (completion)
            completion(object, NO);
        return;
    }
#if DEBUG
    NSLog(@"Response (%li): %@", (long)[(NSHTTPURLResponse *)response statusCode], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    NSNumber *headerUserId = [[(NSHTTPURLResponse *)response allHeaderFields] objectForKey:@"X-PAM-UserId"];
    NSNumber *myUserId = [[NSUserDefaults standardUserDefaults] objectForKey:@"userId"];
    
    // Delete entity if server doesn't have it.
    if (statusCode == 404 && [object isKindOfClass:[NSManagedObject class]])
    {
        [(NSManagedObject *)object MR_deleteEntity];
        if (completion)
            completion(nil, NO);
    }
    else if (statusCode == 401 || (headerUserId != nil && headerUserId.intValue != myUserId.intValue))
    {
        [[NSUserDefaults standardUserDefaults] synchronize];
        if ([self isAuthenticating])
        {
            if (requestDict)
            {
#if DEBUG
                NSLog(@"Added request to queue while authenticating");
#endif
                @synchronized (self.requestQueue) {
                    if ([self.requestQueue containsObject:requestDict]) // This has been tried before. Remove it instead.
                        [self.requestQueue removeObject:requestDict];
                    else
                        [self.requestQueue addObject:requestDict];
                }
            }
            else if (completion)
                completion(object, NO);
            return;
        }
        
        BOOL queued = NO;
        @synchronized ([TSNRESTManager class]) {
            self.isAuthenticating = YES;
            if (requestDict)
            {
                queued = YES;
                @synchronized(self.requestQueue) {
                    [self.requestQueue addObject:requestDict];
                }
            }
        }
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(userClass)] && [self.delegate respondsToSelector:@selector(loginCompleteBlock)])
            [TSNRESTLogin loginWithDefaultRefreshTokenAndUserClass:[self.delegate userClass] url:[self.delegate authURL] completion:[self.delegate loginCompleteBlock]];
        else if ([self.delegate respondsToSelector:@selector(userClass)])
            [TSNRESTLogin loginWithDefaultRefreshTokenAndUserClass:[self.delegate userClass] url:[self.delegate authURL]];
        else
            [TSNRESTLogin loginWithDefaultRefreshTokenAndUserClass:nil url:[self.delegate authURL]];
        if (completion && !queued)
            completion(object, NO);
        
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"prev401"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] > 204)
    {
        NSLog(@"Creation/updated of object failed (Status code %li).", (long)[(NSHTTPURLResponse *)response statusCode]);
        if (error)
            NSLog(@"Error: %@", [error localizedDescription]);
        if (object)
        {
            [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                id contextObject = [object MR_inContext:localContext];
                if ([contextObject respondsToSelector:NSSelectorFromString(@"dirty")])
                    [contextObject setValue:@1 forKey:@"dirty"];
            } completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"modelUpdated" object:nil];
                });
            }];
        }
        
        NSMutableDictionary *failDict = [[NSMutableDictionary alloc] init];
        if (object)
        {
            [failDict addEntriesFromDictionary:@{@"class":NSStringFromClass([object class]),
                                                 @"object":object}];
        }
        if (responseDict)
            [failDict addEntriesFromDictionary:@{@"response":responseDict}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"APIRequestFailed" object:Nil userInfo:failDict];
        if (completion)
            completion(nil, NO);
    }
    else
    {
        if (object && [object respondsToSelector:NSSelectorFromString(@"dirty")])
        {
            [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                id contextObject = [object MR_inContext:localContext];
                [contextObject setValue:@0 forKey:@"dirty"];
            }];
        }
        
        [TSNRESTParser parseAndPersistDictionary:responseDict withCompletion:^{
            [[(NSManagedObject *)object managedObjectContext] refreshObject:object mergeChanges:YES];
            
            if (completion)
                completion(object, YES);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"modelUpdated" object:nil];
        } forObject:object];
    }
}

- (NSDictionary *)dictionaryFromObject:(id)object withObjectMap:(TSNRESTObjectMap *)objectMap optionalKeys:(NSArray *)optionalKeys
{
    return [object dictionaryRepresentationWithOptionalKeys:optionalKeys excludingKeys:nil];
}

- (NSURLRequest *)requestForObject:(NSManagedObject *)object
{
    return [self requestForObject:object optionalKeys:nil];
}

- (NSURLRequest *)requestForObject:(NSManagedObject *)object optionalKeys:(NSArray *)optionalKeys
{
    return [NSURLRequest requestForObject:object optionalKeys:optionalKeys];
}

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
