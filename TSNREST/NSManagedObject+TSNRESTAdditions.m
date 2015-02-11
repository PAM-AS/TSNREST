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
#import "NSManagedObject+TSNRESTSerializer.h"
#import "NSURLSessionDataTask+TSNRESTDataTask.h"

static void * InFlightPropertyKey = &InFlightPropertyKey;

@implementation NSManagedObject (TSNRESTAdditions)

- (BOOL)inFlight {
    return [objc_getAssociatedObject(self, InFlightPropertyKey) boolValue];
}

- (void)setInFlight:(BOOL)inFlight {
    objc_setAssociatedObject(self, InFlightPropertyKey, [NSNumber numberWithBool:inFlight], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)get:(NSString *)propertyKey
{
    if ([self respondsToSelector:NSSelectorFromString(@"dirty")])
    {
        if ([[self valueForKey:@"dirty"] isKindOfClass:[NSNumber class]] && [[self valueForKey:@"dirty"] isEqualToNumber:@2])
        {
            if (self.inFlight)
                return nil;
            
            [self setInFlight:YES];
            NSManagedObject __weak *weakSelf = self;
            [self refreshWithCompletion:^(id object, BOOL success) {
                [weakSelf setInFlight:NO];
            }];
            return nil;
        }
    }
    
    SEL selector = NSSelectorFromString(propertyKey);
    if ([self respondsToSelector:selector])
        return [self valueForKey:propertyKey];

    return nil;
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
#if DEBUG
        NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
        NSLog(@"Triggering fault on %@ %@ (dirty is %@)", NSStringFromClass(self.class), [self valueForKey:idKey], [self valueForKey:@"dirty"]);
#endif
        [self refreshWithCompletion:completion];
    }
    else if (completion)
    {
        completion(self, YES);
    }
}

- (void)checkForDeletion:(void (^)(BOOL hasBeenDeleted))completion
{
    NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:self.class];
    NSString *url = [[[[[[TSNRESTManager sharedManager] configuration] baseURL] absoluteString] stringByAppendingPathComponent:map.serverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", [self valueForKey:idKey]]];
    
#if DEBUG
    NSLog(@"Checking deletion for %@ (%@) at %@", NSStringFromClass(self.class), [self valueForKey:idKey], url);
#endif
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSManagedObject __weak *weakSelf = self;
    
    NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
        completion(NO);
    } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
        if (statusCode == 404) {
            [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                [[weakSelf MR_inContext:localContext] MR_deleteEntity];
            } completion:^(BOOL contextDidSave, NSError *error) {
                if (completion)
                    completion(YES);
            }];
        }
        else {
            if (completion)
                completion(NO);
        }
    } finally:nil parseResult:NO];
    [task resume];
}

- (void)refresh
{
    [self refreshWithCompletion:nil];
}

- (void)refreshWithCompletion:(void (^)(id object, BOOL success))completion {
    [self refreshWithQueryParams:nil completion:completion];
}

- (void)refreshWithQueryParams:(NSDictionary *)queryParameters completion:(void (^)(id object, BOOL success))completion {
    NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
#if DEBUG
    NSLog(@"Refreshing %@ %@", NSStringFromClass(self.class), [self valueForKey:idKey]);
#endif
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:self.class];
    NSURL *url = [NSURL URLWithString:[[[[[[TSNRESTManager sharedManager] configuration] baseURL] absoluteString] stringByAppendingPathComponent:map.serverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", [self valueForKey:idKey]]]];
    
#if DEBUG
    NSLog(@"URL: %@", url);
#endif
    
    if (queryParameters) {
        NSMutableString *queryString = [[NSMutableString alloc] initWithString:@"?"];
        [queryParameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if (queryString.length > 1)
                [queryString appendString:@"&"];
            [queryString appendFormat:@"%@=%@", key, obj];
        }];
        url = [url URLByAppendingQueryString:queryString];
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSManagedObject __weak *weakSelf = self;
    
    NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
        [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
            if ([weakSelf respondsToSelector:NSSelectorFromString(@"dirty")])
                [[weakSelf MR_inContext:localContext] setValue:@0 forKey:@"dirty"];
        }];
        if (completion)
            completion(weakSelf, YES);
    } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
        if (completion)
            completion(weakSelf, NO);
    } finally:nil];
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

+ (void)refresh
{
    [self refreshWithCompletion:nil];
}

+ (void)refreshWithCompletion:(void (^)())completion
{
    // Send NSNotificationCenter push that model will be updated. Send model class as user data.
    
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    
    TSNRESTObjectMap *objectMap = [manager objectMapForClass:[self class]];
    if (!objectMap)
    {
#if DEBUG
        NSLog(@"No objectMap found for class %@", NSStringFromClass([self class]));
#endif
        return;
    }
    NSURL *url = [[manager.configuration baseURL] URLByAppendingPathComponent:[objectMap serverPath]];
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
    
    NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:nil failure:nil finally:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completion)
            completion();
    }];
    [task resume];
}

+ (void)findOnServerByAttribute:(NSString *)objectAttribute value:(id)value completion:(void (^)(NSArray *results))completion
{
    [self findOnServerByAttribute:objectAttribute value:value queryParameters:nil completion:completion];
}

+ (void)findOnServerByAttribute:(NSString *)objectAttribute value:(id)inputValue queryParameters:(NSDictionary *)queryParameters completion:(void (^)(NSArray *results))completion
{
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[self class]];
    
    NSManagedObjectContext *context = nil;
    __block id value = inputValue;
    if ([inputValue isKindOfClass:[NSManagedObject class]]) {
        context = [NSManagedObjectContext MR_context];
        [context performBlockAndWait:^{
            value = [inputValue MR_inContext:context];
        }];
    }
    
    if (!map) {
#if DEBUG
        NSLog(@"Warning: skipped loading for class %@ because of missing object map.", NSStringFromClass([self class]));
#endif
        return;
    }
    
    NSString *webAttribute = [[map objectToWeb] objectForKey:objectAttribute];
    
    __block NSString *queryValue;
    if ([value isKindOfClass:[NSString class]])
        queryValue = (NSString *)value;
    else if ([value isKindOfClass:[NSManagedObject class]]) {
        [context performBlockAndWait:^{
            queryValue = [value valueForKey:[[[TSNRESTManager sharedManager] configuration] localIdName]];
        }];
    }
    
    if (!queryValue) {
#if DEBUG
        NSLog(@"Warning: Could not create valid query for %@ based on key: %@, value: %@", NSStringFromClass([self class]), objectAttribute, value);
#endif
        return;
    }
    
    NSString *query = [NSString stringWithFormat:@"?%@=%@", webAttribute, queryValue];
    if (queryParameters) {
        NSMutableString *queryWithParameters = [NSMutableString stringWithString:query];
        for (NSString *key in queryParameters) {
            [queryWithParameters appendFormat:@"&%@=%@", key, [queryParameters valueForKey:key]];
        }
        query = [NSString stringWithString:queryWithParameters];
    }
    
    NSURL *url = [[[[[TSNRESTManager sharedManager] configuration] baseURL] URLByAppendingPathComponent:[map serverPath]] URLByAppendingQueryString:query];
    
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *customHeaders = [[TSNRESTManager sharedManager] customHeaders];
    if (customHeaders)
        [customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request addValue:obj forHTTPHeaderField:key];
        }];
    
#if DEBUG
    NSLog(@"Fetching search from URL: %@", url);
    NSLog(@"URL was based on value: %@", queryValue);
#endif
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        [TSNRESTParser parseAndPersistDictionary:dict withCompletion:^{
            // If object, we need to check against the object, not it's ID
            NSPredicate *predicate = nil;
            id referenceObject = nil;
            if ([[(NSObject *)self classOfPropertyNamed:objectAttribute] isSubclassOfClass:[NSManagedObject class]])
            {
                NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
                referenceObject = [[(NSObject *)self classOfPropertyNamed:objectAttribute] MR_findFirstByAttribute:idKey withValue:queryValue];
                predicate = [NSPredicate predicateWithFormat:@"%K = %@", objectAttribute, referenceObject];
            }
            else
            {
                predicate = [NSPredicate predicateWithFormat:@"%K = %@", objectAttribute, queryValue];
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
    
    NSURL *url = [[[[[TSNRESTManager sharedManager] configuration] baseURL] URLByAppendingPathComponent:[map serverPath]] URLByAppendingQueryString:query];
    
    NSLog(@"Asking server for %@", url);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:nil failure:nil finally:^(NSData *data, NSURLResponse *response, NSError *error) {
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
