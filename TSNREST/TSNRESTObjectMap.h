//
//  TSNRESTObjectMap.h
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 06.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TSNRESTObjectMap : NSObject

@property (nonatomic, strong) Class classToMap;
@property (nonatomic, strong) NSString *serverPath;
@property (nonatomic, strong) NSString *pushKey;
@property (nonatomic, strong) NSString *permanentQuery;

@property (nonatomic, copy) void (^mappingBlock)(id object, NSManagedObjectContext *context, NSDictionary *dict);
@property (nonatomic, copy) void (^reverseMappingBlock)(id object, NSMutableDictionary *dict);

@property (nonatomic,strong) NSMutableDictionary *objectToWeb;
@property (nonatomic,strong) NSMutableDictionary *booleans;
@property (nonatomic,strong) NSMutableDictionary *enumMaps;
@property (nonatomic,strong) NSArray *readOnlyKeys;

- (id)initWithClass:(Class)classToInit;

- (void)mapClass:(Class)classToMap toWebKey:(NSString *)webKey;
- (void)mapObjectKeys:(NSArray *)objectKeys toWebKeys:(NSArray *)webKeys;
- (void)mapObjectKey:(NSString *)objectKey toWebKey:(NSString *)webKey;
- (void)mapObjectKey:(NSString *)objectKey toWebKeys:(NSArray *)webKey;

// Conveniences
- (void)mapIdenticalKey:(NSString *)key;
- (void)mapIdenticalKeys:(NSArray *)keys;

- (void)mapCamelCasedObjectKeyToUnderscoreWebKey:(NSString *)key;
- (void)mapCamelCasedObjectKeysToUnderscoreWebKeys:(NSArray *)keys;

// Extras
-(void)addBoolean:(NSString *)boolean; // Tells TSNREST to convert boolean to NSNumber for Core Data
-(void)addEnumMap:(NSDictionary *)enumMap forKey:(NSString *)key;
/*
 Planning to replace addBoolean: with runtime check later.
 */

// Logging
- (void)logObjectMappings;

@end
