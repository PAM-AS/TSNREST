//
//  NSManagedObject+TSNRESTSerializer.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 02.12.14.
//
//

#import "NSManagedObject+TSNRESTSerializer.h"
#import "TSNRESTManager.h"
#import "NSObject+PropertyClass.h"

@implementation NSManagedObject (TSNRESTSerializer)

- (NSDictionary *)dictionaryRepresentation {
    return [self dictionaryRepresentationWithOptionalKeys:nil];
}

- (NSDictionary *)dictionaryRepresentationWithOptionalKeys:(NSArray *)optionalKeys {
    return [self dictionaryRepresentationWithOptionalKeys:optionalKeys excludingKeys:nil];
}

- (NSDictionary *)dictionaryRepresentationWithOptionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys {
    if (self.isDeleted)
        return @{};
    
    __block NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
    
    // Special snowflakes
    if ([self valueForKey:idKey])
        [dataDict setValue:[self valueForKey:idKey] forKey:@"id"];
    if ([self respondsToSelector:NSSelectorFromString(@"uuid")] && [self valueForKey:@"uuid"])
        [dataDict setValue:[self valueForKey:@"uuid"] forKey:@"uuid"];
    
    TSNRESTManager *manager = [TSNRESTManager sharedManager];
    TSNRESTObjectMap *objectMap = [manager objectMapForClass:[self class]];
    
    [objectMap.objectToWeb enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (objectMap.reverseMappingBlock) // Check for custom mapping block and run it.
        {
            objectMap.reverseMappingBlock(self, dataDict);
        }
        
        if ([[objectMap readOnlyKeys] containsObject:key] || [excludingKeys containsObject:key]) // Readonly or explicitly excluded. Skip.
        {
            return;
        }
        
        /* Check optionals.
         optionalKeys in objectmap specifies which are optional,
         optionalKeys as parameter to this function specifies which one we want to send anyway.
         */
        if ([[objectMap optionalKeys] containsObject:key] && (!optionalKeys || ![optionalKeys containsObject:key]))
        {
            return;
        }
        
        Class classType = [self classOfPropertyNamed:key];
        
        // Enums
        if ([[objectMap enumMaps] valueForKey:key])
        {
            NSLog(@"Found enum map for %@!", key);
            NSDictionary *enumMap = [[objectMap enumMaps] valueForKey:key];
            NSString *value = [enumMap objectForKey:[self valueForKey:key]];
            if ([self respondsToSelector:NSSelectorFromString(key)] && [self valueForKey:key] && value)
            [dataDict setObject:value forKey:obj];
            
        }
        else if (classType == [NSString class] || classType == [NSNumber class])
        {
            if ([self respondsToSelector:NSSelectorFromString(key)] && [self valueForKey:key])
            [dataDict setObject:[self valueForKey:key] forKey:obj];
        }
        else if (classType == [NSDate class] && [self valueForKey:key])
        {
            NSDate *date = [self valueForKey:key];
            [dataDict setObject:[manager.ISO8601Formatter stringFromDate:date] forKey:obj];
        }
        else if ([classType isSubclassOfClass:[NSManagedObject class]] && [[self valueForKey:key] respondsToSelector:NSSelectorFromString(idKey)] && [[self valueForKey:key] valueForKey:idKey])
        {
            NSNumber *systemId = [[self valueForKey:key] valueForKey:idKey];
            if (systemId)
            [dataDict setObject:systemId forKey:obj];
        }
        else if ([obj isKindOfClass:[NSArray class]])
        {
            for (NSString *string in obj)
            {
                id objectForKey = [self valueForKey:key];
                if (string && objectForKey)
                [dataDict setObject:objectForKey forKey:string];
            }
        }
        
        // Hack to create bools
        if ([objectMap.booleans objectForKey:key])
            [dataDict setObject:[NSNumber numberWithBool:[[dataDict objectForKey:obj] boolValue]] forKey:obj];
    }];
    
#if DEBUG
    NSLog(@"Created dict: %@", dataDict);
#endif
    
    return [NSDictionary dictionaryWithDictionary:dataDict];
}

- (NSData *)jsonDataRepresentation {
    return [self jsonDataRepresentationWithOptionalKeys:nil excludingKeys:nil];
}

- (NSData *)jsonDataRepresentationWithOptionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys {
    NSError *error = [[NSError alloc] init];
    return [NSJSONSerialization dataWithJSONObject:[self dictionaryRepresentationWithOptionalKeys:optionalKeys excludingKeys:excludingKeys] options:0 error:&error];
}

- (NSString *)jsonStringRepresentation {
    return [self jsonStringRepresentationWithOptionalKeys:nil excludingKeys:nil];
}

- (NSString *)jsonStringRepresentationWithOptionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys {
    return [[NSString alloc] initWithData:[self jsonDataRepresentationWithOptionalKeys:optionalKeys excludingKeys:excludingKeys] encoding:NSUTF8StringEncoding];
}

@end
