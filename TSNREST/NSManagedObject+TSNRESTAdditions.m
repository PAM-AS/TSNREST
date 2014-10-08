//
//  NSManagedObject+TSNRESTAdditions.m
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import "NSManagedObject+TSNRESTAdditions.h"
#import "TSNRESTParser.h"
#import "TSNRESTObjectMap.h"
#import "NSObject+PropertyClass.h"
#import <objc/runtime.h>
#import "RSSwizzle.h"

static void * InFlightPropertyKey = &InFlightPropertyKey;

@implementation NSManagedObject (TSNRESTAdditions)

- (BOOL)inFlight {
    return [objc_getAssociatedObject(self, InFlightPropertyKey) boolValue];
}

- (void)setInFlight:(BOOL)inFlight {
    objc_setAssociatedObject(self, InFlightPropertyKey, [NSNumber numberWithBool:inFlight], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/*
+ (void)addMagicGetters
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        for (NSString *propertyName in [[self class] propertyNames])
        {
            if ([propertyName isEqualToString:@"inFlight"] || [propertyName isEqualToString:@"dirty"] || [propertyName isEqualToString:@"systemId"])
                continue;
            
            SEL selector = NSSelectorFromString(propertyName);
            class_getInstanceMethod([self class], selector);
            
            RSSwizzleInstanceMethod([class class], selector, RSSWReturnType(id), nil, RSSWReplacement({
                NSLog(@"Swizzle the shizzle");
                return RSSWCallOriginal();
            }), 0, nil);
        }
    });
}
 */

- (id)get:(NSString *)propertyKey
{
    if ([self respondsToSelector:NSSelectorFromString(@"dirty")])
    {
        if ([[self valueForKey:@"dirty"] isKindOfClass:[NSNumber class]] && [[self valueForKey:@"dirty"] isEqualToNumber:@2])
        {
            if (self.inFlight)
                return nil;
            
            [self setInFlight:YES];
            [self refreshWithCompletion:^(id object, BOOL success) {
                [self setInFlight:NO];
            }];
            return nil;
        }
    }
    
    SEL selector = NSSelectorFromString(propertyKey);
    if ([self respondsToSelector:selector])
        return [self valueForKey:propertyKey];

    return nil;
}

- (void)saveAndPersist
{
    [self saveAndPersistWithSuccess:nil failure:nil finally:nil];
}

- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock
{
    [self saveAndPersistWithSuccess:successBlock failure:failureBlock finally:nil];
}

- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock
{
    [self saveAndPersistWithSuccess:successBlock failure:failureBlock finally:finallyBlock optionalKeys:nil];
}

- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock optionalKeys:(NSArray *)optionalKeys
{
    if (self.inFlight)
    {
#if DEBUG
        NSLog(@"Skipping save of %@ %@ because object already is in flight.", NSStringFromClass([self class]), [self valueForKey:@"systemId"]);
#endif
        if (successBlock)
            successBlock(self);
        if (finallyBlock)
            finallyBlock(self);
        return;
    }
    
    self.inFlight = YES;
    
    // Catch changes made externally
    [self.managedObjectContext MR_saveToPersistentStoreAndWait];

    NSURLSession *currentSession = [NSURLSession sharedSession];
    
    if ([self respondsToSelector:NSSelectorFromString(@"uuid")])
    {
        if (![self valueForKey:@"uuid"])
        {
            [self setValue:[[NSUUID UUID] UUIDString] forKey:@"uuid"];
            [self.managedObjectContext MR_saveOnlySelfAndWait];
        }
    }
    
    [[TSNRESTManager sharedManager] startLoading:@"persistWithCompletion:session:"];
    NSURLRequest *request = [[TSNRESTManager sharedManager] requestForObject:self optionalKeys:optionalKeys];
    NSURLSessionDataTask *dataTask = [currentSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [[TSNRESTManager sharedManager] handleResponse:response withData:data error:error object:self completion:^(id object, BOOL success) {
            [[TSNRESTManager sharedManager] endLoading:@"persistWithCompletion:session:"];
            self.inFlight = NO;
            [self.managedObjectContext MR_saveToPersistentStoreWithCompletion:nil];
            if (success && successBlock)
            {
                successBlock(self);
            }
            else if (failureBlock && !success)
            {
                failureBlock(self);
            }
            if (finallyBlock)
                finallyBlock(self);
        }];
#if DEBUG
        if (error)
        {
            NSLog(@"Data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            NSLog(@"Response: %@", response);
            NSLog(@"Error: %@", [error userInfo]);
        }
#endif
    }];
    [dataTask resume];
}

- (void)deleteFromServer
{
    [[TSNRESTManager sharedManager] deleteObjectFromServer:self];
}

- (void)deleteFromServerWithCompletion:(void (^)(id object, BOOL success))completion
{
    [[TSNRESTManager sharedManager] deleteObjectFromServer:self completion:completion];
}

- (void)faultIfNeeded
{
    [self faultIfNeededWithCompletion:nil];
}

- (void)faultIfNeededWithCompletion:(void (^)(id object, BOOL success))completion
{
    SEL dirtyIdSelector = sel_registerName("dirty");
    if ([self respondsToSelector:dirtyIdSelector] && [[self valueForKey:@"dirty"] isEqualToNumber:@2])
    {
        NSLog(@"Triggering fault on %@ %@ (dirty is %@)", NSStringFromClass(self.class), [self valueForKey:@"systemId"], [self valueForKey:@"dirty"]);
        [self refreshWithCompletion:completion];
    }
    else if (completion)
    {
        completion(self, YES);
    }
}

- (void)checkForDeletion:(void (^)(BOOL hasBeenDeleted))completion
{
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:self.class];
    NSString *url = [[(NSString *)[[TSNRESTManager sharedManager] baseURL] stringByAppendingPathComponent:map.serverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", [self valueForKey:@"systemId"]]];
    
#if DEBUG
    NSLog(@"Checking deletion for %@ (%@) at %@", NSStringFromClass(self.class), [self valueForKey:@"systemId"], url);
#endif
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([(NSHTTPURLResponse *)response statusCode] == 404)
            [self MR_deleteEntity];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion([(NSHTTPURLResponse *)response statusCode] == 404);
        });
    }];
    [task resume];
}

- (void)refresh
{
    [self refreshWithCompletion:nil];
}

- (void)refreshWithCompletion:(void (^)(id object, BOOL success))completion
{
#if DEBUG
    NSLog(@"Refreshing %@ %@", NSStringFromClass(self.class), [self valueForKey:@"systemId"]);
#endif
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:self.class];
    NSString *url = [[(NSString *)[[TSNRESTManager sharedManager] baseURL] stringByAppendingPathComponent:map.serverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", [self valueForKey:@"systemId"]]];
    
    NSLog(@"URL: %@", url);
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    [[TSNRESTManager sharedManager] startLoading:[NSString stringWithFormat:@"refreshWithCompletion for %@ %@", NSStringFromClass(self.class), [self valueForKey:@"systemId"]]];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [[TSNRESTManager sharedManager] handleResponse:response withData:data error:error object:self completion:^(id object, BOOL success) {
            if (completion)
            {
                [[TSNRESTManager sharedManager] endLoading:[NSString stringWithFormat:@"refreshWithCompletion for %@ %@", NSStringFromClass(self.class), [self valueForKey:@"systemId"]]];
                completion(nil, success);
            }
        }];
    }];
    [task resume];
}

+ (NSArray *)propertyNames
{
    id class = [self class];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(class, &outCount);
    NSMutableArray *names = [[NSMutableArray alloc] initWithCapacity:outCount];
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *propertyNameString = [NSString stringWithFormat:@"%s", property_getName(property)];
        [names addObject:propertyNameString];
    }
    return [NSArray arrayWithArray:names];
}

- (NSDictionary *)dictionaryRepresentation
{
    return [[TSNRESTManager sharedManager] dictionaryFromObject:self withObjectMap:[[TSNRESTManager sharedManager] objectMapForClass:[self class]] optionalKeys:nil];
}

- (NSString *)JSONRepresentation
{
    NSError *error = [[NSError alloc] init];
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:[self dictionaryRepresentation] options:0 error:&error];
    NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
    return JSONString;
}

+ (void)refresh
{
    [self refreshWithCompletion:nil];
}

+ (void)refreshWithCompletion:(void (^)())completion
{
    // Send NSNotificationCenter push that model will be updated. Send model class as user data.
    
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    [manager startLoading:[NSString stringWithFormat:@"refreshWithCompletion for class %@", NSStringFromClass(self.class)]];
    
    TSNRESTObjectMap *objectMap = [manager objectMapForClass:[self class]];
    if (!objectMap)
    {
#if DEBUG
        NSLog(@"No objectMap found for class %@", NSStringFromClass([self class]));
#endif
        return;
    }
    NSURL *url = [[NSURL URLWithString:[manager baseURL]] URLByAppendingPathComponent:[objectMap serverPath]];
    if (objectMap.permanentQuery)
        url = [url URLByAppendingQueryString:objectMap.permanentQuery];
    
#if DEBUG
    NSLog(@"Checking for new %@ at %@", NSStringFromClass([self class]), [url absoluteString]);
#endif
    
    // Fetch array of dicts from JSON
    //NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    //[request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if ([[TSNRESTManager sharedManager] customHeaders])
        [[[TSNRESTManager sharedManager] customHeaders] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request addValue:obj forHTTPHeaderField:key];
        }];
    
    [[TSNRESTManager sharedManager] runAutoAuthenticatingRequest:request completion:^(BOOL success, BOOL newData, BOOL retrying) {
        if (completion)
            completion();
        [[TSNRESTManager sharedManager] endLoading:[NSString stringWithFormat:@"refreshWithCompletion for class %@", NSStringFromClass(self.class)]];
    }];
    
    /*
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Sending response to handler: (Status code %li).", (long)[(NSHTTPURLResponse *)response statusCode]);
        [[TSNRESTManager sharedManager] handleResponse:response withData:data error:error object:nil completion:^(id object, BOOL success) {
            if (completion)
                completion();
            [[TSNRESTManager sharedManager] endLoading:@"refreshWithCompletion"];
        }];
    }];
    [task resume];
     */

}

+ (void)findOnServerByAttribute:(NSString *)objectAttribute value:(NSString *)value completion:(void (^)(NSArray *results))completion
{
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[self class]];
    
    NSString *webAttribute = [[map objectToWeb] objectForKey:objectAttribute];
    
    NSString *query = [NSString stringWithFormat:@"?%@=%@", webAttribute, value];
    
    NSURL *url = [[[NSURL URLWithString:(NSString *)[[TSNRESTManager sharedManager] baseURL]] URLByAppendingPathComponent:[map serverPath]] URLByAppendingQueryString:query];
    
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSLog(@"Fetching search from URL: %@", url);
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        [TSNRESTParser parseAndPersistDictionary:dict withCompletion:^{
            // If object, we need to check against the object, not it's ID
            NSPredicate *predicate = nil;
            id referenceObject = nil;
            if ([[(NSObject *)self classOfPropertyNamed:objectAttribute] isSubclassOfClass:[NSManagedObject class]])
            {
                referenceObject = [[(NSObject *)self classOfPropertyNamed:objectAttribute] MR_findFirstByAttribute:@"systemId" withValue:value];
                predicate = [NSPredicate predicateWithFormat:@"%K = %@", objectAttribute, referenceObject];
            }
            else
            {
                predicate = [NSPredicate predicateWithFormat:@"%K = %@", objectAttribute, value];
            }
            
            NSArray *objects = [[self class] MR_findAllWithPredicate:predicate];
            if (completion)
                completion(objects);
        }];
    }];
    [task resume];
}

+ (void)findOnServerByAttribute:(NSString *)objectAttribute pluralizedWebAttribute:(NSString *)pluralizedWebAttribute values:(NSArray *)values completion:(void (^)(NSArray *results))completion
{
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[self class]];
    
    NSMutableString *query = [[NSMutableString alloc] initWithString:@"?"];
    
    for (NSString *value in values)
    {
        if (query.length > 1)
            [query appendString:@"&"];
        [query appendString:[NSString stringWithFormat:@"%@[]=%@", pluralizedWebAttribute, value]];
    }
    
    NSURL *url = [[[NSURL URLWithString:(NSString *)[[TSNRESTManager sharedManager] baseURL]] URLByAppendingPathComponent:[map serverPath]] URLByAppendingQueryString:query];
    
    NSLog(@"Asking server for %@", url);
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        [TSNRESTParser parseAndPersistDictionary:dict withCompletion:^{
            // If object, we need to check against the object, not it's ID
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", objectAttribute, values];
            
            NSArray *objects = [[self class] MR_findAllWithPredicate:predicate];
            if (completion)
                completion(objects);
        }];
    }];
    [task resume];
}

@end
