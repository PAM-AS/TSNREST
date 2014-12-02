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
    NSNumber *systemId = [self valueForKey:@"systemId"];
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
        else if (statusCode == 401) {
            void(^successBlock)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
                completion(self, YES);
            };
            void(^failureBlock)(NSData *, NSURLResponse *, NSError *, NSInteger) = ^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
                completion(self, NO);
            };
            [[TSNRESTManager sharedManager] addRequestToAuthQueue:@{@"request":request, @"successBlock":successBlock, @"failureBlock":failureBlock}];
        }
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
