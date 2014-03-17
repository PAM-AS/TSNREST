//
//  NSURL+TSNRESTAdditions.h
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 12.03.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (TSNRESTAdditions)

- (NSURL *)URLByAppendingQueryString:(NSString *)queryString;

@end
