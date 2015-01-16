//
//  NSString+TSNRESTContains.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 16.01.15.
//
//

#import "NSString+TSNRESTContains.h"

@implementation NSString (TSNRESTContains)

- (BOOL)containsString:(NSString *)string
               options:(NSStringCompareOptions)options {
    NSRange rng = [self rangeOfString:string options:options];
    return rng.location != NSNotFound;
}

- (BOOL)containsString:(NSString *)string {
    return [self containsString:string options:0];
}

- (BOOL)containsAllStrings:(NSArray *)strings
{
    for (NSString *string in strings)
    {
        if (![self containsString:string])
            return NO;
    }
    return YES;
}

- (BOOL)containsAnyString:(NSArray *)strings
{
    for (NSString *string in strings)
    {
        if ([self containsString:string])
            return YES;
    }
    return NO;
}

@end
