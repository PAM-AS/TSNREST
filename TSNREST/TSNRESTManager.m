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
#import "NSString+TSNRESTAdditions.h"

@interface TSNRESTManager ()

@property (atomic) int loadingRetainCount;

@property (nonatomic, strong) NSMutableArray *requestQueue;

#warning workaround timer
@property (nonatomic) NSTimer *resetLoadingTimer;

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
        [(TSNRESTManager *)_sharedObject setRequestQueue:[[NSMutableArray alloc] init]];
    });
    
    // returns the same object each time
    return _sharedObject;
}

- (void)startLoading:(NSString *)identifier
{
    if (self.loadingRetainCount == 0)
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"startLoadingAnimation" object:nil];
        });
    self.loadingRetainCount++;
#if DEBUG
    NSLog(@"LoadingRetain: %i New loading starts: %@", self.loadingRetainCount, identifier);
#endif
    [self checkResetLoadingTimer];
}

- (void)endLoading:(NSString *)identifier
{
    self.loadingRetainCount--;
    if (self.loadingRetainCount == 0)
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"stopLoadingAnimation" object:nil];
        });
#if DEBUG
    NSLog(@"LoadingRetain: %i Loading done: %@", self.loadingRetainCount, identifier);
#endif
    [self checkResetLoadingTimer];
}

- (void)checkResetLoadingTimer
{
    NSLog(@"Scheduling resetTimer");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.resetLoadingTimer)
            [self.resetLoadingTimer invalidate];
        if (self.loadingRetainCount != 0)
        {
            self.resetLoadingTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(resetLoading) userInfo:nil repeats:NO];
        }
        [self.resetLoadingTimer setTolerance:2];
    });
}

- (void)resetLoading
{
    self.loadingRetainCount = 0;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"stopLoadingAnimation" object:nil];
}

#pragma mark - Getters & setters
- (dispatch_queue_t)serialQueue
{
    if (!_serialQueue)
        _serialQueue = dispatch_queue_create("as.pam.pam.serialQueue", DISPATCH_QUEUE_SERIAL);
    return _serialQueue;
}

- (BOOL)isLoading
{
    return (self.loadingRetainCount > 0);
}

- (NJISO8601Formatter *)ISO8601Formatter
{
    if (!_ISO8601Formatter)
        _ISO8601Formatter = [[NJISO8601Formatter alloc] init];
    return _ISO8601Formatter;
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
    if (!self.customHeaders)
        self.customHeaders = [[NSMutableDictionary alloc] init];
    [self.customHeaders setObject:header forKey:key];
}

- (TSNRESTObjectMap *)objectMapForClass:(Class)classToFind
{
    NSLog(@"Finding object map for class %@", NSStringFromClass(classToFind));
    return [self.objectMaps objectForKey:NSStringFromClass(classToFind)];
}

- (TSNRESTObjectMap *)objectMapForServerPath:(NSString *)path
{
    for (NSString *key in self.objectMaps)
    {
        TSNRESTObjectMap *map = [self.objectMaps objectForKey:key];
        if ([map.serverPath isEqualToString:path])
            return map;
    }
    
    return nil;
}

- (TSNRESTObjectMap *)objectMapForPushKey:(NSString *)path
{
    for (NSString *key in self.objectMaps)
    {
        TSNRESTObjectMap *map = [self.objectMaps objectForKey:key];
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
    NSNumber *systemId = [object valueForKey:@"systemId"];
    if (!systemId)
    {
        [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
            [[object MR_inContext:localContext] MR_deleteEntity];
        } completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion)
                    completion(object, YES);
            });
        }];
        return;
    }
    
    TSNRESTObjectMap *objectMap = [self objectMapForClass:[object class]];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    if (self.customHeaders)
        [self.customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request addValue:obj forHTTPHeaderField:key];
        }];
    [request setHTTPMethod:@"DELETE"];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@/%@", self.baseURL, objectMap.serverPath, systemId]];
    [request setURL:url];
    
#if DEBUG
    NSLog(@"Sending delete action for %@ to %@", systemId, [url absoluteString]);
#endif
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([(NSHTTPURLResponse *)response statusCode] == 404) // Assume object isn't on server yet. Delete locally.
        {
            dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
#if DEBUG
                NSLog(@"Object attempted deleted, assume success (404).");
#endif
                [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                    [[object MR_inContext:localContext] MR_deleteEntity];
                } completion:^(BOOL success, NSError *error) {
                    if (completion)
                        completion(object, YES);
                }];
            });
        }
        else if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] > 204)
        {
#if DEBUG
            NSLog(@"Deletion of object failed (Status code %li).", (long)[(NSHTTPURLResponse *)response statusCode]);
            if (error)
                NSLog(@"Error: %@", [error localizedDescription]);
            
            NSLog(@"Response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif
            
            if (completion)
                completion(object, NO);
        }
        else
        {
            dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
                NSLog(@"Object successfully deleted.");
                [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                    [[object MR_inContext:localContext] MR_deleteEntity];
                } completion:^(BOOL success, NSError *error) {
                    if (completion)
                        completion(object, YES);
                }];
            });
        }
    }];
    [dataTask resume];
}

#pragma mark - Network helpers
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

- (void)flushLoadingRetains
{
    self.loadingRetainCount = 0;
}

- (void)flushQueuedRequests
{
    @synchronized(self.requestQueue) {
        self.loadingRetainCount -= (int)self.requestQueue.count;
        [self.requestQueue removeAllObjects];
    }
}

- (void)runQueuedRequests
{
    if (self.isAuthenticating)
    {
        NSLog(@"Can't run queued requests, still not done authenticating.");
        return;
    }
    
    NSArray *requestQueue = nil;

    @synchronized(self.requestQueue)
    {
#if DEBUG
        NSLog(@"Running %lu requests from queue", (unsigned long)self.requestQueue.count);
#endif
    
        requestQueue = [NSArray arrayWithArray:self.requestQueue];
    }
    
    for (NSDictionary *dictionary in requestQueue)
    {
        if ([[dictionary objectForKey:@"request"] isKindOfClass:[NSMutableURLRequest class]])
        {
            NSURLSession *session = [dictionary objectForKey:@"session"];
            if (!session)
                session = [NSURLSession sharedSession];
            
            NSMutableURLRequest *request = [dictionary objectForKey:@"request"];
            
            [request setAllHTTPHeaderFields:self.customHeaders];
            
            NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:[dictionary objectForKey:@"completion"]];
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
        else
        {
            [[TSNRESTManager sharedManager] endLoading:@"handleResponse generic (no completion block provided)"];
        }
        
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
            dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
                [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                    id contextObject = [object MR_inContext:localContext];
                    if ([contextObject respondsToSelector:NSSelectorFromString(@"dirty")])
                        [contextObject setValue:@1 forKey:@"dirty"];
                } completion:^(BOOL success, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"modelUpdated" object:nil];
                    });
                }];
            });
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
        else
        {
            [[TSNRESTManager sharedManager] endLoading:@"handleResponse generic (no completion block provided)"];
        }
    }
    else
    {
        if (object && [object respondsToSelector:NSSelectorFromString(@"dirty")])
        {
            dispatch_sync([[TSNRESTManager sharedManager] serialQueue], ^{
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    id contextObject = [object MR_inContext:localContext];
                    [contextObject setValue:@0 forKey:@"dirty"];
                }];
            });
        }
        
        [TSNRESTParser parseAndPersistDictionary:responseDict withCompletion:^{
            [[(NSManagedObject *)object managedObjectContext] refreshObject:object mergeChanges:YES];
            
            if (completion)
                completion(object, YES);
            else
            {
                [[TSNRESTManager sharedManager] endLoading:@"handleResponse generic (no completion block provided)"];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"modelUpdated" object:nil];
        } forObject:object];
    }
}

- (NSDictionary *)dictionaryFromObject:(id)object withObjectMap:(TSNRESTObjectMap *)objectMap optionalKeys:(NSArray *)optionalKeys
{
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    
    if ([object isDeleted] || [object hasBeenDeleted])
        return @{};
    
    if ([object valueForKey:@"systemId"])
        [dataDict setValue:[object valueForKey:@"systemId"] forKey:@"id"];
    if ([object respondsToSelector:NSSelectorFromString(@"uuid")] && [object valueForKey:@"uuid"])
        [dataDict setValue:[object valueForKey:@"uuid"] forKey:@"uuid"];
    
    // Fill data dict - the dict that we convert to JSON
    [objectMap.objectToWeb enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        // We get the value of the object (the actual data), and set the web key from the objectToWeb dictionary value.
        
        Class classType = [object classOfPropertyNamed:key];
        
        if (objectMap.reverseMappingBlock) // Check for custom mapping block and run it.
        {
            objectMap.reverseMappingBlock(object, dataDict);
        }
        
        if ([[objectMap readOnlyKeys] containsObject:key]) // Readonly. Skip.
        {
            return;
        }
        
        /* Check optionals.
         optionalKeys in objectmap specifies which are optional,
         optionalKeys as parameter to this function specifies which one we want to send anyway.
         */
        if ([[objectMap optionalKeys] containsObject:key] && (!optionalKeys || ![optionalKeys containsObject:key]))
        {
            return;
        }
        
        if ([[objectMap enumMaps] valueForKey:key])
        {
            NSLog(@"Found enum map for %@!", key);
            NSDictionary *enumMap = [[objectMap enumMaps] valueForKey:key];
            NSString *value = [enumMap objectForKey:[(NSManagedObject *)object valueForKey:key]];
            if ([object respondsToSelector:NSSelectorFromString(key)] && [object valueForKey:key] && value)
                [dataDict setObject:value forKey:obj];
            
        }
        else if (classType == [NSString class] || classType == [NSNumber class])
        {
            if ([object respondsToSelector:NSSelectorFromString(key)] && [object valueForKey:key])
                [dataDict setObject:[(NSManagedObject *)object valueForKey:key] forKey:obj];
        }
        else if (classType == [NSDate class] && [object valueForKey:key])
        {
            NSDate *date = [object valueForKey:key];
            [dataDict setObject:[self.ISO8601Formatter stringFromDate:date] forKey:obj];
        }
        else if ([classType isSubclassOfClass:[NSManagedObject class]] && [[object valueForKey:key] respondsToSelector:NSSelectorFromString(@"systemId")] && [[object valueForKey:key] valueForKey:@"systemId"])
        {
            NSNumber *systemId = [[object valueForKey:key] valueForKey:@"systemId"];
            if (systemId)
                [dataDict setObject:systemId forKey:obj];
        }
        else if ([obj isKindOfClass:[NSArray class]])
        {
            for (NSString *string in obj)
            {
                id objectForKey = [(NSManagedObject *)object valueForKey:key];
                if (string && objectForKey)
                    [dataDict setObject:objectForKey forKey:string];
            }
        }
        
        NSLog(@"Adding %@:%@ to dict (class: %@)", key, obj, NSStringFromClass(classType));
        
        // Hack to create bools
        if ([objectMap.booleans objectForKey:key])
            [dataDict setObject:[NSNumber numberWithBool:[[dataDict objectForKey:obj] boolValue]] forKey:obj];
    }];
    NSLog(@"Created dict: %@", dataDict);
    return [NSDictionary dictionaryWithDictionary:dataDict];
}

- (NSURLRequest *)requestForObject:(id)object
{
    return [self requestForObject:object optionalKeys:nil];
}

- (NSURLRequest *)requestForObject:(id)object optionalKeys:(NSArray *)optionalKeys
{
    [[(NSManagedObject *)object managedObjectContext] refreshObject:object mergeChanges:NO];
    NSLog(@"Persisting object %@ (context: %@)", [object class], [object managedObjectContext]);
    TSNRESTObjectMap *objectMap = [self objectMapForClass:[object class]];
    NSLog(@"ObjectMap: %@", objectMap);
    NSDictionary *dataDict = [self dictionaryFromObject:object withObjectMap:objectMap optionalKeys:optionalKeys];
    
    NSData *JSONData = nil;
    if (dataDict.count > 0)
    {
        NSDictionary *wrapper = [[NSDictionary alloc] initWithObjectsAndKeys:dataDict, [NSStringFromClass([object class]) stringByConvertingCamelCaseToUnderscore], nil];
        NSError *error = [[NSError alloc] init];
        JSONData = [NSJSONSerialization dataWithJSONObject:wrapper options:0 error:&error];
        NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
        NSLog(@"Created JSON string from object: %@", JSONString);
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (self.customHeaders)
        [self.customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request addValue:obj forHTTPHeaderField:key];
        }];
    if (JSONData)
    {
        NSLog(@"Sending JSON: %@", [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding]);
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:JSONData];
    }
    
    NSURL *url = [NSURL URLWithString:self.baseURL];
    if (objectMap.serverPath)
        url = [url URLByAppendingPathComponent:objectMap.serverPath];
    else
        return nil;
    
    if ([object valueForKey:@"systemId"] && [[object valueForKey:@"systemId"] isKindOfClass:[NSNumber class]])
    {
        NSString *pathComponent = [NSString stringWithFormat:@"%@", [object valueForKey:@"systemId"]];
        if (pathComponent)
            url = [url URLByAppendingPathComponent:pathComponent];
    }
    
    [request setURL:url];
    
    NSLog(@"URL: %@", [[request URL] absoluteString]);
    return request;
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
