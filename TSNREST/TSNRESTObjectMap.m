//
//  TSNRESTObjectMap.m
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import "TSNRESTObjectMap.h"
#import "NSString+TSNRESTAdditions.h"

@implementation TSNRESTObjectMap

- (id)initWithClass:(Class)classToInit
{
    self = [self init];
    if(self) {
        self.classToMap = classToInit;
        self.serverPath = [NSStringFromClass(classToInit) lowercaseString];
    }
    return(self);
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self.objectToWeb = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)mapObjectKeys:(NSArray *)objectKeys toWebKeys:(NSArray *)webKeys
{
    for (int i = 0; i < objectKeys.count && i < webKeys.count; i++)
    {
        [self mapObjectKeys:[objectKeys objectAtIndex:i] toWebKeys:[webKeys objectAtIndex:i]];
    }
}

- (void)mapClass:(Class)classToMap toWebKey:(NSString *)webKey
{
    [self.objectToWeb setObject:webKey forKey:NSStringFromClass(classToMap)];
}

- (void)mapObjectKey:(NSString *)objectKey toWebKey:(NSString *)webKey
{
    [self.objectToWeb setObject:webKey forKey:objectKey];
}

- (void)mapObjectKey:(NSString *)objectKey toWebKeys:(NSArray *)webKey
{
    [self.objectToWeb setObject:webKey forKey:objectKey];
}

- (void)mapIdenticalKey:(NSString *)key
{
    [self mapObjectKey:key toWebKey:key];
}

- (void)mapIdenticalKeys:(NSArray *)keys
{
    for (NSString *key in keys)
        [self mapIdenticalKey:key];
}

- (void)mapCamelCasedObjectKeyToUnderscoreWebKey:(NSString *)key
{
    [self mapObjectKey:key toWebKey:[key stringByConvertingCamelCaseToUnderscore]];
}

- (void)mapCamelCasedObjectKeysToUnderscoreWebKeys:(NSArray *)keys
{
    for (NSString *key in keys)
        [self mapCamelCasedObjectKeyToUnderscoreWebKey:key];
}

-(void)addBoolean:(NSString *)boolean
{
    if (!self.booleans)
        self.booleans = [[NSMutableDictionary alloc] init];
    [self.booleans setObject:@YES forKey:boolean];
}

-(void)addEnumMap:(NSDictionary *)enumMap forKey:(NSString *)key
{
    if (!self.enumMaps)
        self.enumMaps = [[NSMutableDictionary alloc] init];
    [self.enumMaps setObject:enumMap forKey:key];
}

/*
 Quickmap 
 Check if class
 if(class_isMetaClass(object_getClass(obj)))
 */

- (void)logObjectMappings
{
    for (NSString *key in self.objectToWeb)
    {
        NSMutableString *logString = [NSMutableString stringWithFormat:@"Object: %@", key];
        for (long i = 15-key.length; i > 0; i--)
            [logString appendString:@" "];
        NSString *value = [self.objectToWeb objectForKey:key];
        [logString appendFormat:@"Web: %@", value];
        NSLog(@"%@", logString);
    }
}

@end
