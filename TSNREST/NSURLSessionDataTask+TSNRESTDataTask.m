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

+ (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request success:(void (^)(NSData *data, NSURLResponse *response, NSError *error))successBlock failure:(void (^)(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode))failureBlock finally:(void (^)(NSData *data, NSURLResponse *response, NSError *error))finallyBlock {
    return [self dataTaskWithRequest:request success:successBlock failure:failureBlock finally:finallyBlock parseResult:YES];
}

+ (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request success:(void (^)(NSData *data, NSURLResponse *response, NSError *error))successBlock failure:(void (^)(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode))failureBlock finally:(void (^)(NSData *data, NSURLResponse *response, NSError *error))finallyBlock parseResult:(BOOL)parseResult {
    return [self dataTaskWithRequest:request success:successBlock failure:failureBlock finally:finallyBlock parseResult:parseResult attempt:@0];
}


+ (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request success:(void (^)(NSData *data, NSURLResponse *response, NSError *error))successBlock failure:(void (^)(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode))failureBlock finally:(void (^)(NSData *data, NSURLResponse *response, NSError *error))finallyBlock parseResult:(BOOL)parseResult attempt:(NSNumber *)attempt {
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    [manager addRequestToLoading:request];
    return [[manager URLSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]])
            statusCode = [(NSHTTPURLResponse *)response statusCode];
        else {
            NSError *jsonError = [[NSError alloc] init];
            NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if ([responseData objectForKey:@"statusCode"]) {
                statusCode = [[responseData objectForKey:@"statusCode"] integerValue];
            }
        }
        if (statusCode == 401) { // Not authenticated
#if DEBUG
            NSLog(@"Authorization error: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif
            if (request)
            {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                [dict setObject:[NSNumber numberWithInteger:attempt.integerValue+1] forKey:@"attempt"];
                NSLog(@"Reauthing, attempt %@", [dict objectForKey:@"attempt"]);
                [dict setObject:request forKey:@"request"];
                [dict setObject:@(parseResult) forKey:@"parseResult"];
                if (successBlock)
                    [dict setObject:successBlock forKey:@"successBlock"];
                if (failureBlock)
                    [dict setObject:failureBlock forKey:@"failureBlock"];
                if (finallyBlock)
                    [dict setObject:finallyBlock forKey:@"finallyBlock"];
                [manager addRequestToAuthQueue:[NSDictionary dictionaryWithDictionary:dict]];
            }
            [manager.session loginWithDefaultInfo];
            [manager removeRequestFromLoading:request];
        }
        else if (statusCode < 200 || statusCode > 204) { // No success
#if DEBUG
            NSLog(@"Request to %@ failed.", response.URL.absoluteString);
            NSLog(@"Error from server: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif
            if (failureBlock) {
                failureBlock(data, response, error, statusCode);
            }
            if (finallyBlock)
                finallyBlock(data, response, error);
            [manager removeRequestFromLoading:request];
        }
        else {
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
#if DEBUG
            NSLog(@"Got response from server: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif
            if (parseResult) {
                [TSNRESTParser parseAndPersistDictionary:responseDict withCompletion:^{
                    if (successBlock)
                        successBlock(data, response, error);
                    if (finallyBlock)
                        finallyBlock(data, response, error);
                    [manager removeRequestFromLoading:request];
                }];
            } else {
                if (successBlock)
                    successBlock(data, response, error);
                if (finallyBlock)
                    finallyBlock(data, response, error);
                [manager removeRequestFromLoading:request];
            }
        }
    }];
}

@end
