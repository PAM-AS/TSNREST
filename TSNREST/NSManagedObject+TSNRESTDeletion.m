//
//  NSManagedObject+TSNRESTDeletion.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 02.12.14.
//
//

#import "NSManagedObject+TSNRESTDeletion.h"
#import "MagicalRecord.h"
#import "MagicalRecord+Actions.h"
#import "NSManagedObject+MagicalRecord.h"
#import "NSURLRequest+TSNRESTConveniences.h"
#import "NSURLSessionDataTask+TSNRESTDataTask.h"
#import "TSNRESTManager.h"

@implementation NSManagedObject (TSNRESTDeletion)

- (void)deleteFromServer {
    [self deleteFromServerWithCompletion:nil];
}

- (void)deleteFromServerWithCompletion:(void (^)(id object, BOOL success))completion {
    NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
    NSNumber *systemId = [self valueForKey:idKey];
    if (!systemId)
    {
#if DEBUG
        NSLog(@"Deleting object locally - it doesn't exist on server.");
#endif
        [self deleteLocallyWithCompletion:completion];
        return;
    }
    
    NSMutableURLRequest *request = [[NSURLRequest requestForObject:self] mutableCopy];
    [request setValue:nil forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"DELETE"];
    [request setHTTPBody:nil];
    
    NSURLSessionDataTask *task = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self deleteLocallyWithCompletion:completion];
    } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
        if (statusCode == 404)
            [self deleteLocallyWithCompletion:completion];

        // 401 was handled here before, but is now handled by the dataTaskWithRequest:success:failure:finally convenience method on NSURLSessionDataTask+TSNRESTDatatask
        
        else if (completion)
            completion(self, NO);
    } finally:nil];
    [task resume];
}

- (void)deleteLocallyWithCompletion:(void (^)(id object, BOOL success))completion {
    [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
        [[self MR_inContext:localContext] MR_deleteEntity];
    } completion:^(BOOL contextDidSave, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion(self, YES);
        });
    }];
}

@end
