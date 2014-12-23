//
//  TSNRESTManagerConfiguration.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 23.12.14.
//
//

#import "TSNRESTManagerConfiguration.h"

@implementation TSNRESTManagerConfiguration

- (NSString *)localIdName {
    if (_localIdName)
        return _localIdName;
    return @"systemId";
}

@end
