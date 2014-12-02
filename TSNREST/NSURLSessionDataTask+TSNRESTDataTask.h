//
//  NSURLSessionDataTask+TSNRESTDataTask.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 02.12.14.
//
//

#import <Foundation/Foundation.h>

@interface NSURLSessionDataTask (TSNRESTDataTask)

+ (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request success:(void (^)(NSData *data, NSURLResponse *response, NSError *error))successBlock failure:(void (^)(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode))failureBlock finally:(void (^)(NSData *data, NSURLResponse *response, NSError *error))finallyBlock;

@end
