//
//  NSString+TSNRESTCasing.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import "NSString+TSNRESTCasing.h"

@implementation NSString (TSNRESTCasing)

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

- (NSString *)camelCasedString {
    NSArray *strings = [self componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -_"]];
    if (!strings || strings.count == 0)
        return self;
    NSMutableString *camelCased = [[NSMutableString alloc] initWithCapacity:self.length];
    for (NSString *string in strings) {
        [camelCased appendString:[string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[string substringToIndex:1] uppercaseString]]];
    }
    
    return [NSString stringWithString:camelCased];
}

@end
