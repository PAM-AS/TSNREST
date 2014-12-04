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

@implementation NSURLRequest (TSNRESTConveniences)

+ (NSURLRequest *)requestForObject:(NSManagedObject *)object {
    return [self requestForObject:object optionalKeys:nil];
}

+ (NSURLRequest *)requestForObject:(NSManagedObject *)object optionalKeys:(NSArray *)optionalKeys {
    return [self requestForObject:object optionalKeys:optionalKeys excludingKeys:nil];
}

+ (NSURLRequest *)requestForObject:(NSManagedObject *)object optionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys
{
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    
    [[object managedObjectContext] refreshObject:object mergeChanges:NO];
    TSNRESTObjectMap *objectMap = [manager objectMapForClass:[object class]];

    NSDictionary *dataDict = [object dictionaryRepresentation];
    
    NSData *JSONData = nil;
    if (dataDict.count > 0)
    {
        NSDictionary *wrapper = [[NSDictionary alloc] initWithObjectsAndKeys:dataDict, [NSStringFromClass([object class]) stringByConvertingCamelCaseToUnderscore], nil];
        NSError *error = [[NSError alloc] init];
        JSONData = [NSJSONSerialization dataWithJSONObject:wrapper options:0 error:&error];
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *customHeaders = [manager customHeaders];
    if (customHeaders)
    [customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [request addValue:obj forHTTPHeaderField:key];
    }];
    if (JSONData)
    {
#if DEBUG
        NSLog(@"Sending JSON: %@", [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding]);
#endif
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:JSONData];
    }
    
    NSURL *url = [NSURL URLWithString:manager.baseURL];
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
    
    NSLog(@"URL: %@", request.URL.absoluteString);
    
    return request;
}

@end