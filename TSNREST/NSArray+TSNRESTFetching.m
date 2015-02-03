//
//  NSArray+TSNRESTFetching.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.02.15.
//
//

#import "NSArray+TSNRESTFetching.h"
#import "TSNRESTManager.h"
#import "NSURLRequest+TSNRESTConveniences.h"
#import "NSURLSessionDataTask+TSNRESTDataTask.h"
#import "NSArray+TSNRESTDeserializer.h"

@implementation NSArray (TSNRESTFetching)

- (void)reloadContainedManagedObjects {
    [self reloadContainedManagedObjectsWithCompletion:nil];
}

- (void)reloadContainedManagedObjectsWithCompletion:(void(^)(NSArray *updatedObjects))completion {
    NSArray *ids = [self valueForKey:TSNRESTManager.sharedManager.configuration.localIdName];
    if (ids.count == 0) {
        if (completion)
            completion(nil);
        return;
    }
    
    Class class = [[self firstObject] class];
    NSURLRequest *request = [NSURLRequest requestForClass:class ids:ids];
    
    NSURLSession *session = NSURLSession.sharedSession;
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]] && ([(NSHTTPURLResponse *)response statusCode] > 204 || [(NSHTTPURLResponse *)response statusCode] < 200)) {
            if (completion)
                completion(nil);
        }
        
        NSError *jsonError = [[NSError alloc] init];
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        TSNRESTObjectMap *map = [TSNRESTManager.sharedManager objectMapForClass:class];
        if (![responseDict valueForKey:map.serverPath]) {
            if (completion)
                completion(nil);
        } else {
            NSArray *jsonObjects = [responseDict valueForKey:map.serverPath];
            NSArray *arrayOfReturnedIds = [jsonObjects valueForKey:@"id"];
            
            [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                [jsonObjects deserializeWithMap:map inContext:localContext optimize:NO];
            } completion:^(BOOL contextDidSave, NSError *error) {
                NSManagedObjectContext *context = [NSManagedObjectContext MR_context];
                [context performBlock:^{
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", arrayOfReturnedIds];
                    NSArray *objects = [class MR_findAllWithPredicate:predicate inContext:context];
                    if (completion)
                        completion(objects);
                }];
            }];
        }
    }];
    [task resume];
}

@end
