//
//  NSString+TSNRESTCasing.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 03.12.14.
//
//

#import <Foundation/Foundation.h>

@interface NSString (TSNRESTCasing)

- (NSString *)stringByConvertingCamelCaseToUnderscore;

// CamelCases strings as smartly as possible, including spaces, dashes and underscores. Also keeps existing CamelCasing.
- (NSString *)camelCasedString;

@end
