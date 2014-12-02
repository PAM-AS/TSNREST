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
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
        completion(NO);
    } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
        if (statusCode == 404) {
            [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                [self MR_deleteEntity];
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

- (void)refreshWithCompletion:(void (^)(id object, BOOL success))completion
{
#if DEBUG
    NSLog(@"Refreshing %@ %@", NSStringFromClass(self.class), [self valueForKey:@"systemId"]);
#endif
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:self.class];
    NSString *url = [[(NSString *)[[TSNRESTManager sharedManager] baseURL] stringByAppendingPathComponent:map.serverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", [self valueForKey:@"systemId"]]];
    
#if DEBUG
    NSLog(@"URL: %@", url);
#endif
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completion)
            completion(self, YES);
    } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
        if (completion)
            completion(self, NO);
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
    
    NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:nil failure:nil finally:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completion)
            completion();
    }];
    [task resume];
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
