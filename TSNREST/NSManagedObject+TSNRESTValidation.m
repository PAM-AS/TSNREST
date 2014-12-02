//
//  NSManagedObject+TSNRESTValidation.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 26.11.14.
//
//

#import "NSManagedObject+TSNRESTValidation.h"
#import "TSNRESTManager.h"

@implementation NSManagedObject (TSNRESTValidation)

- (BOOL)isValid
{
    if (self.isDeleted)
        return NO;
    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[self class]];
    if (map.validationBlock)
        return map.validationBlock(self);
    else
        return YES;
}

@end
