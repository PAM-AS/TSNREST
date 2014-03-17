//
//  NSString+TSNRESTAdditions.m
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 21.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import "NSString+TSNRESTAdditions.h"

@implementation NSString (TSNRESTAdditions)

- (NSString *)stringByConvertingCamelCaseToUnderscore
{
    NSString *firstCapChar = [[self substringToIndex:1] lowercaseString];
    NSString *string = [self stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:firstCapChar];
    NSCharacterSet *upperCaseSet = [NSCharacterSet uppercaseLetterCharacterSet];
    while ([string rangeOfCharacterFromSet:upperCaseSet].location != NSNotFound)
    {
        NSRange range = [string rangeOfCharacterFromSet:upperCaseSet];
        string = [string stringByReplacingCharactersInRange:range withString:[NSString stringWithFormat:@"_%@", [[string substringWithRange:range] lowercaseString]]];
    }
    return string;
}

@end
