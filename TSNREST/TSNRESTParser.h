//
//  TSNRESTParser.h
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 04.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSNRESTObjectMap.h"
#import "TSNRESTManager.h"

@interface TSNRESTParser : NSObject

+ (void)parseAndPersistDictionary:(NSDictionary *)dict;
+ (void)parseAndPersistDictionary:(NSDictionary *)dict withCompletion:(void (^)())completion;
+ (void)parseAndPersistDictionary:(NSDictionary *)dict withCompletion:(void (^)())completion forObject:(id)object;

@end
