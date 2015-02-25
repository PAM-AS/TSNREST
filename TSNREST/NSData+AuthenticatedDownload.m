//
//  NSData+AuthenticatedDownload.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 25.02.15.
//
//

#import "NSData+AuthenticatedDownload.h"
#import "NSURLRequest+TSNRESTConveniences.h"

@implementation NSData (TSNRESTAuthenticatedDownload)

+ (NSData *)dataWithContentsOfURL:(NSURL *)url authenticated:(BOOL)authenticated {
    if (!authenticated)
        return [NSData dataWithContentsOfURL:url];
    
    NSMutableURLRequest *request = [NSMutableURLRequest authenticatedRequest];
    request.URL = url;
    NSURLResponse *response = [[NSURLResponse alloc] init];
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    return data;
}

@end
