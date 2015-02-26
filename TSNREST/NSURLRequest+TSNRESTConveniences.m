//
//  NSURLRequest+TSNRESTConveniences.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 02.12.14.
//
//

#import "NSURLRequest+TSNRESTConveniences.h"
#import "TSNRESTManager.h"
#import "NSString+TSNRESTCasing.h"
#import "NSManagedObject+TSNRESTSerializer.h"
#import "NSURL+TSNRESTAdditions.h"

@implementation NSURLRequest (TSNRESTConveniences)

+ (NSMutableURLRequest *)_baseURLRequest {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.timeoutInterval = 15;
    NSDictionary *customHeaders = TSNRESTManager.sharedManager.customHeaders;
    if (customHeaders)
        [customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request addValue:obj forHTTPHeaderField:key];
        }];
    return request;
}





+ (NSURLRequest *)requestForObject:(NSManagedObject *)object {
    return [self requestForObject:object optionalKeys:nil];
}

+ (NSURLRequest *)requestForObject:(NSManagedObject *)object optionalKeys:(NSArray *)optionalKeys {
    return [self requestForObject:object optionalKeys:optionalKeys excludingKeys:nil];
}

+ (NSURLRequest *)requestForObject:(NSManagedObject *)object optionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys
{
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    
    if (!object) {
        return nil;
    }
    
    TSNRESTObjectMap *objectMap = [manager objectMapForClass:[object class]];

    NSDictionary *dataDict = [object dictionaryRepresentationWithOptionalKeys:optionalKeys excludingKeys:excludingKeys];
    
    NSData *JSONData = nil;
    if (dataDict.count > 0)
    {
        NSDictionary *wrapper = [[NSDictionary alloc] initWithObjectsAndKeys:dataDict, [NSStringFromClass([object class]) stringByConvertingCamelCaseToUnderscore], nil];
        NSError *error = [[NSError alloc] init];
        JSONData = [NSJSONSerialization dataWithJSONObject:wrapper options:0 error:&error];
    }
    
    NSMutableURLRequest *request = [self _baseURLRequest];
    
    if (JSONData)
    {
#if DEBUG
        NSLog(@"Sending JSON: %@", [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding]);
#endif
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:JSONData];
    }
    
    NSURL *url = [manager.configuration baseURL];
    if (objectMap.serverPath)
    url = [url URLByAppendingPathComponent:objectMap.serverPath];
    else
    return nil;
    
    NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
    if ([object valueForKey:idKey] && [[object valueForKey:idKey] isKindOfClass:[NSNumber class]])
    {
        NSString *pathComponent = [NSString stringWithFormat:@"%@", [object valueForKey:idKey]];
        if (pathComponent)
        url = [url URLByAppendingPathComponent:pathComponent];
    }
    
    [request setURL:url];
    
#if DEBUG
    NSLog(@"URL: %@", request.URL.absoluteString);
#endif
    
    return request;
}

+ (NSURLRequest *)requestForClass:(Class)class ids:(NSArray *)ids {
    if (!ids) {
        return [self requestForClass:class query:nil];
    }
    NSString *queryParams = [NSString stringWithFormat:@"?ids[]=%@", [ids componentsJoinedByString:@"&ids[]="]];
    return [self requestForClass:class query:queryParams];
}

+ (NSURLRequest *)requestForClass:(Class)class query:(NSString *)query {
    if (!class) {
        return nil;
    }
    
    NSString *serverPath = [[TSNRESTManager.sharedManager objectMapForClass:class] serverPath];
    NSURL *url = [TSNRESTManager.sharedManager.configuration.baseURL URLByAppendingPathComponent:serverPath];
    if (query) {
        url = [url URLByAppendingQueryString:query];
    }
    
    NSMutableURLRequest *request = [self _baseURLRequest];
    request.URL = url;
    request.HTTPMethod = @"GET";
    return request;
}

+ (NSMutableURLRequest *)authenticatedRequest {
    return [self _baseURLRequest];
}

@end
