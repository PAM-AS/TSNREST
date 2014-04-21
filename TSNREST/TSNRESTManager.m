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
    });
    
    // returns the same object each time
    return _sharedObject;
}

#pragma mark - Getters & setters
- (dispatch_queue_t)serialQueue
{
    if (!_serialQueue)
        _serialQueue = dispatch_queue_create("as.pam.pam.serialQueue", DISPATCH_QUEUE_SERIAL);
    return _serialQueue;
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


- (void)deleteObjectFromServer:(id)object
{
    [self deleteObjectFromServer:object completion:nil];
}

- (void)deleteObjectFromServer:(id)object completion:(void (^)(id object, BOOL success))completion
{
    TSNRESTObjectMap *objectMap = [self objectMapForClass:[object class]];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (self.customHeaders)
        [self.customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request addValue:obj forHTTPHeaderField:key];
        }];
    [request setHTTPMethod:@"DELETE"];
    
    NSNumber *systemId = [object valueForKey:@"systemId"];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@/%@", self.baseURL, objectMap.serverPath, systemId]];
    [request setURL:url];
    
    NSLog(@"Sending delete action for %@ to %@", systemId, [url absoluteString]);
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([(NSHTTPURLResponse *)response statusCode] == 404) // Assume object isn't on server yet. Delete locally.
        {
            dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
                NSLog(@"Object attempted deleted, assume success (404).");
                [object deleteEntity];
                NSError *aerror = [[NSError alloc] init];
                [[object managedObjectContext] save:&aerror];
                if (completion)
                    completion(object, YES);
            });
        }
        else if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] > 204)
        {
            NSLog(@"Deletion of object failed (Status code %li).", (long)[(NSHTTPURLResponse *)response statusCode]);
            if (error)
                NSLog(@"Error: %@", [error localizedDescription]);
            if (completion)
                completion(object, NO);
        }
        else
        {
            dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
                NSLog(@"Object successfully deleted.");
                [object deleteEntity];
                NSError *aerror = [[NSError alloc] init];
                [[object managedObjectContext] save:&aerror];
                if (completion)
                    completion(object, YES);
            });
        }
    }];
    [dataTask resume];
}

#pragma mark - helpers
- (void)handleResponse:(NSURLResponse *)response withData:(NSData *)data error:(NSError *)error object:(id)object completion:(void (^)(id object, BOOL success))completion
{
    NSNumber *systemId = [object valueForKey:@"systemId"];
    Class objectClass = [object class];
    
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
    NSLog(@"Response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    NSNumber *headerUserId = [[(NSHTTPURLResponse *)response allHeaderFields] objectForKey:@"X-PAM-UserId"];
    NSNumber *myUserId = [[NSUserDefaults standardUserDefaults] objectForKey:@"userId"];
    
    if (statusCode == 401 || (headerUserId != nil && headerUserId.intValue != myUserId.intValue))
    {
        if (self.delegate && [self.delegate loginCompleteBlock])
            [TSNRESTLogin loginWithDefaultRefreshTokenAndUserClass:[self.delegate userClass] url:[self.delegate authURL] completion:[self.delegate loginCompleteBlock]];
        else
            [TSNRESTLogin loginWithDefaultRefreshTokenAndUserClass:[self.delegate userClass] url:[self.delegate authURL]];
        if (completion)
            completion(object, NO);
    }
    else if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] > 204)
    {
        NSLog(@"Creation/updated of object failed (Status code %li).", (long)[(NSHTTPURLResponse *)response statusCode]);
        if (error)
            NSLog(@"Error: %@", [error localizedDescription]);
        if (object)
        {
            dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    id contextObject = [object inContext:localContext];
                    if ([contextObject respondsToSelector:NSSelectorFromString(@"dirty")])
                        [contextObject setValue:@1 forKey:@"dirty"];
                }];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"modelUpdated" object:nil];
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
    }
    else
    {
        if (object && [object respondsToSelector:NSSelectorFromString(@"dirty")])
        {
            dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    id contextObject = [object inContext:localContext];
                    [contextObject setValue:@0 forKey:@"dirty"];
                }];
            });
        }
        
        [TSNRESTParser parseAndPersistDictionary:responseDict withCompletion:^{
            id newObject = nil;
            
            if (object && objectClass && systemId)
            {
                newObject = [objectClass findFirstByAttribute:@"systemId" withValue:systemId];
                if ([newObject respondsToSelector:NSSelectorFromString(@"name")])
                    NSLog(@"Object name: %@", [newObject valueForKey:@"name"]);
                NSLog(@"Object: %@", newObject);
            }
            
            if (completion)
                completion(newObject, YES);
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"stopLoadingAnimation" object:nil];
                });
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"modelUpdated" object:nil];
        } forObject:object];
    }
}

- (NSDictionary *)dictionaryFromObject:(id)object withObjectMap:(TSNRESTObjectMap *)objectMap
{
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    
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
            [dataDict setObject:[date sam_ISO8601String] forKey:obj];
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
    [[(NSManagedObject *)object managedObjectContext] refreshObject:object mergeChanges:NO];
    NSLog(@"Persisting object %@ (context: %@)", [object class], [object managedObjectContext]);
    TSNRESTObjectMap *objectMap = [self objectMapForClass:[object class]];
    NSLog(@"ObjectMap: %@", objectMap);
    NSDictionary *dataDict = [self dictionaryFromObject:object withObjectMap:objectMap];
    
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
    
    NSURL *url = [NSURL URLWithString:[self.baseURL stringByAppendingPathComponent:objectMap.serverPath]];
    
    if ([object valueForKey:@"systemId"] && [[object valueForKey:@"systemId"] isKindOfClass:[NSNumber class]])
        url = [url URLByAppendingPathComponent:[NSString stringWithFormat:@"%@", [object valueForKey:@"systemId"]]];
    else
        NSLog(@"WTFCAKES %@'s systemId is %@", object, [object valueForKey:@"systemId"]);
    
    [request setURL:url];
    
    NSLog(@"URL: %@", [[request URL] absoluteString]);
    return request;
}

- (void)resetDataStore
{
    [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
        NSLog(@"Starting reset");
        for (NSEntityDescription *entity in [[NSManagedObjectModel defaultManagedObjectModel] entities])
        {
            id thisClass = NSClassFromString(entity.name);
            if ([thisClass respondsToSelector:NSSelectorFromString(@"truncateAllInContext:")])
                [thisClass truncateAllInContext:localContext];
        }
    } completion:^(BOOL success, NSError *error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"updateBadges" object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"dataReset" object:nil];
    }];
}

@end
