//
//  NSURL+TSNRESTAdditions.m
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 12.03.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import "NSURL+TSNRESTAdditions.h"

@implementation NSURL (TSNRESTAdditions)

- (NSURL *)URLByAppendingQueryString:(NSString *)queryString {
    if (![queryString length]) {
        return self;
    }
    
    NSString *string = [[self absoluteString] stringByAppendingString:queryString];
    NSURL *newURL = [NSURL URLWithString:[string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    return newURL;
}

@end