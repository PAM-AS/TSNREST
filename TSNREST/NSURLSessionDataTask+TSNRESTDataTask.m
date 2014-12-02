//
//  NSURLSessionDataTask+TSNRESTDataTask.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 02.12.14.
//
//

#import "NSURLSessionDataTask+TSNRESTDataTask.h"
#import "TSNRESTManager.h"
#import "TSNRESTParser.h"

@implementation NSURLSessionDataTask (TSNRESTDataTask)

+ (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request success:(void (^)(NSData *data, NSURLResponse *response, NSError *error))successBlock failure:(void (^)(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode))failureBlock finally:(void (^)(NSData *data, NSURLResponse *response, NSError *error))finallyBlock
{
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    return [[manager URLSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 401) { // Not authenticated
            [manager addRequestToAuthQueue:@{@"request":request,@"successBlock":successBlock,@"failureBlock":failureBlock,@"finallyBlock":finallyBlock}];
            [manager reAuthenticate];
        }
        else if (statusCode < 200 || statusCode > 204) { // No success
            if (failureBlock) {
                failureBlock(data, response, error, statusCode);
            }
            if (finallyBlock)
                finallyBlock(data, response, error);
        }
        else {
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            [TSNRESTParser parseAndPersistDictionary:responseDict withCompletion:^{
                if (successBlock)
                    successBlock(data, response, error);
                if (finallyBlock)
                    finallyBlock(data, response, error);
            }];
        }
    }];
}

@end
