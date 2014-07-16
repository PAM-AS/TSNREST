//
//  NSSet+TSNRESTAdditions.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 16.07.14.
//
//

#import "NSSet+TSNRESTAdditions.h"
#import "NSArray+TSNRESTAdditions.h"

@implementation NSSet (TSNRESTAdditions)

- (void)faultAllIfNeeded
{
    [[self allObjects] faultGroup];
}

@end
