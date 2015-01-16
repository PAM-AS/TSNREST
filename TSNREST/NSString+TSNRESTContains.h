//
//  NSString+TSNRESTContains.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 16.01.15.
//
//

#import <Foundation/Foundation.h>

@interface NSString (TSNRESTContains)

- (BOOL)containsString:(NSString *)string;
- (BOOL)containsString:(NSString *)string
options:(NSStringCompareOptions)options;
- (BOOL)containsAllStrings:(NSArray *)strings;
- (BOOL)containsAnyString:(NSArray *)strings;

@end
