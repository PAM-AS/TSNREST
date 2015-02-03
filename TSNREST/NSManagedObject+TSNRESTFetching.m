//
//  NSManagedObject+TSNRESTFetching.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import "NSManagedObject+TSNRESTFetching.h"
#import "NSManagedObject+MagicalFinders.h"
#import "NSManagedObject+MagicalRecord.h"
#import "NSManagedObjectContext+MagicalThreading.h"
#import "TSNRESTManager.h"
#import "TSNRESTParser.h"

@implementation NSManagedObject (TSNRESTFetching)

+ (NSManagedObject *)findOrCreateBySystemId:(NSNumber *)systemId inContext:(NSManagedObjectContext *)context {
    if (!context) {
        __block NSManagedObject *object = nil;
        [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
            object = [self _findOrCreateBySystemId:systemId inContext:localContext];
        }];
        return object;
    }
    else {
        return [self _findOrCreateBySystemId:systemId inContext:context];
    }
}

+ (NSManagedObject *)_findOrCreateBySystemId:(NSNumber *)systemid inContext:(NSManagedObjectContext *)context {
    NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
    NSManagedObject *object = [self MR_findFirstByAttribute:idKey withValue:systemid inContext:context];
    if (!object) {
        object = [self MR_createEntityInContext:context];
        [object setValue:systemid forKey:idKey];
    }
    return object;
}

+ (void)findOnServerById:(NSNumber *)systemId completion:(void(^)(NSManagedObject *object))completion {
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[self class]];
    
    if (!map) {
#if DEBUG
        NSLog(@"Warning: skipped loading for class %@ because of missing object map.", NSStringFromClass([self class]));
#endif
        return;
    }
    NSURL *url = [[[[[TSNRESTManager sharedManager] configuration] baseURL] URLByAppendingPathComponent:[map serverPath]] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@", systemId]];
        
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
    NSLog(@"URL was based on value: %@", systemId);
#endif
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        [TSNRESTParser parseAndPersistDictionary:dict withCompletion:^{
            NSManagedObject *object = [[self class] MR_findFirstByAttribute:TSNRESTManager.sharedManager.configuration.localIdName withValue:systemId];
            if (completion)
                completion(object);
        }];
    }];
    [task resume];
}

@end
