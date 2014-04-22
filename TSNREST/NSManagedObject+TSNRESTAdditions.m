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

@implementation NSManagedObject (TSNRESTAdditions)

- (void)persist
{
    [self persistWithCompletion:nil];
}

- (void)persistWithCompletion:(void (^)(id object, BOOL success))completion
{
    NSURLSession *session = [NSURLSession sharedSession];
    [self persistWithCompletion:completion session:session];
}

- (void)persistWithCompletion:(void (^)(id object, BOOL success))completion session:(NSURLSession *)session
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"startLoadingAnimation" object:nil];
    });
    NSURLRequest *request = [[TSNRESTManager sharedManager] requestForObject:self];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [[TSNRESTManager sharedManager] handleResponse:response withData:data error:error object:self completion:completion];
        NSLog(@"Data: %@", data);
        NSLog(@"Response: %@", response);
        if (error)
            NSLog(@"Error: %@", [error userInfo]);
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
    NSLog(@"Testing fault on %@ %@", NSStringFromClass(self.class), [self valueForKey:@"systemId"]);
    SEL dirtyIdSelector = sel_registerName("dirty");
    if ([self respondsToSelector:dirtyIdSelector] && [[self valueForKey:@"dirty"] isEqualToNumber:@2])
    {
        NSLog(@"Triggering fault on %@ %@ (dirty is %@)", NSStringFromClass(self.class), [self valueForKey:@"systemId"], [self valueForKey:@"dirty"]);
        [self refreshWithCompletion:completion];
    }
}

- (void)refresh
{
    [self refreshWithCompletion:nil];
}

- (void)refreshWithCompletion:(void (^)(id object, BOOL success))completion
{
    NSLog(@"Refreshing %@ %@", NSStringFromClass(self.class), [self valueForKey:@"systemId"]);
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:self.class];
    NSString *url = [[(NSString *)[[TSNRESTManager sharedManager] baseURL] stringByAppendingPathComponent:map.serverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", [self valueForKey:@"systemId"]]];
    
    NSLog(@"URL: %@", url);
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [[TSNRESTManager sharedManager] handleResponse:response withData:data error:error object:self completion:^(id object, BOOL success) {
            if (completion)
                completion(nil, success);
        }];
    }];
    [task resume];
}

- (NSString *)JSONRepresentation
{
    NSDictionary *dict = [[TSNRESTManager sharedManager] dictionaryFromObject:self withObjectMap:[[TSNRESTManager sharedManager] objectMapForClass:[self class]]];
    NSError *error = [[NSError alloc] init];
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"startLoadingAnimation" object:nil];
    });
    
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
    
    NSLog(@"Checking for new %@ at %@", NSStringFromClass([self class]), [url absoluteString]);
    
    // Fetch array of dicts from JSON
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if ([[TSNRESTManager sharedManager] customHeaders])
        [[[TSNRESTManager sharedManager] customHeaders] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSLog(@"Added header %@ for %@", obj, key);
            [request addValue:obj forHTTPHeaderField:key];
        }];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Sending response to handler: (Status code %li).", (long)[(NSHTTPURLResponse *)response statusCode]);
        [[TSNRESTManager sharedManager] handleResponse:response withData:data error:error object:nil completion:^(id object, BOOL success) {
            if (completion)
                completion();
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"stopLoadingAnimation" object:nil];
            });
        }];
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
                referenceObject = [[(NSObject *)self classOfPropertyNamed:objectAttribute] findFirstByAttribute:@"systemId" withValue:value];
                predicate = [NSPredicate predicateWithFormat:@"%K = %@", objectAttribute, referenceObject];
            }
            else
            {
                predicate = [NSPredicate predicateWithFormat:@"%K = %@", objectAttribute, value];
            }
            
            NSArray *objects = [[self class] findAllWithPredicate:predicate];
            if (completion)
                completion(objects);
        }];
    }];
    [task resume];
    
}

@end
