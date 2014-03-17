//
//  TSNRESTLogin.h
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 09.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSNRESTManager.h"

@interface TSNRESTLogin : NSObject

+ (void)loginWithDefaultRefreshTokenAndUserClass:(Class)userClass url:(NSString *)url;
+ (void)loginWithDefaultRefreshTokenAndUserClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion;

+ (void)loginWithRefreshToken:(NSString *)token userClass:(Class)userClass url:(NSString *)url;
+ (void)loginWithRefreshToken:(NSString *)token userClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion;

+ (void)loginWithUser:(NSString *)user password:(NSString *)password userClass:(Class)userClass url:(NSString *)url;
+ (void)loginWithUser:(NSString *)user password:(NSString *)password userClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion;
+ (void)loginWithFacebookId:(NSString *)fbId accessToken:(NSString *)accessToken userClass:(Class)userClass url:(NSString *)url;
+ (void)loginWithFacebookId:(NSString *)fbId accessToken:(NSString *)accessToken userClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion;

@end
