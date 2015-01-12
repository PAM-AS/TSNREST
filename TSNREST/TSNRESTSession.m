//
//  TSNRESTSession.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 05.01.15.
//
//

#import "TSNRESTSession.h"
#import "TSNRESTManager.h"
#import "TSNRESTParser.h"
#import "Reachability.h"

@interface TSNRESTSession ()

@property (nonatomic, strong) UILocalNotification *expiryNotification;

@end

@implementation TSNRESTSession

// XCode 6 bug throws us back to the stone age http://stackoverflow.com/questions/24638826/xcode-6-how-to-fix-use-of-undeclared-identifier-for-automatic-property-synthes
@synthesize accessToken = _accessToken;
@synthesize refreshToken = _refreshToken;

static NSString *accessTokenKey = @"access_token";
static NSString *refreshTokenKey = @"refresh_token";
static NSString *userIdKey = @"user_id";
static NSString *expiryKey = @"expires_in";

- (id)init {
    self = [super init];
    self.saveTokensToNSUserDefaults = YES;
    return self;
}

#pragma mark - Getters
- (NSString *)accessToken {
    if (!_accessToken && self.saveTokensToNSUserDefaults) {
        _accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:accessTokenKey];
    }
    return _accessToken;
}

- (NSString *)refreshToken {
    if (!_refreshToken && self.saveTokensToNSUserDefaults) {
        _refreshToken = [[NSUserDefaults standardUserDefaults] objectForKey:refreshTokenKey];
    }
    return _refreshToken;
}

- (NSString *)userId {
    return [[NSUserDefaults standardUserDefaults] objectForKey:userIdKey];
}

#pragma mark - Setters
- (void)setAccessToken:(NSString *)accessToken {
    _accessToken = accessToken;
    if (self.saveTokensToNSUserDefaults) {
        if (_accessToken)
            [[NSUserDefaults standardUserDefaults] setObject:_accessToken forKey:accessTokenKey];
        else
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:accessTokenKey];
    }
    [self addHeader:_accessToken forKey:accessTokenKey];
}

- (void)setRefreshToken:(NSString *)refreshToken {
    _refreshToken = refreshToken;
    if (self.saveTokensToNSUserDefaults) {
        if (_refreshToken)
            [[NSUserDefaults standardUserDefaults] setObject:_refreshToken forKey:refreshTokenKey];
        else
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:refreshTokenKey];
    }
    [self addHeader:_refreshToken forKey:refreshTokenKey];
}

- (NSDictionary *)addHeader:(NSString *)header forKey:(NSString *)key {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.headers];
    [dict setObject:header forKey:key];
    [self setHeaders:[NSDictionary dictionaryWithDictionary:dict]];
    return self.headers;
}

#pragma mark - Logging in
- (NSURL *)authenticationURL {
    return [[[[TSNRESTManager sharedManager] configuration] baseURL] URLByAppendingPathComponent:self.authPath];
}

- (void)loginWithDefaultInfo {
    if (!self.refreshToken) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(sessionLoginFailedWithError:)]) {
            NSError *error = [NSError errorWithDomain:@"as.pam.pam" code:404 userInfo:@{@"log":@"Refresh token not found"}];
            [self.delegate sessionLoginFailedWithError:error];
        }
        return;
    }
    
    NSString *postData = [NSString stringWithFormat:@"grant_type=refresh_token&refresh_token=%@", self.refreshToken];
    [self loginWithPostData:[postData dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)loginWithUsername:(NSString *)username password:(NSString *)password {
    NSString *postData = [NSString stringWithFormat:@"username_or_email=%@&password=%@&grant_type=password", username, password];
    [self loginWithPostData:[postData dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)loginWithFacebookId:(NSString *)facebookId facebookAccessToken:(NSString *)facebookAccessToken {
    NSString *postData = [NSString stringWithFormat:@"fb_user_id=%@&fb_access_token=%@&grant_type=facebook_token", facebookId, facebookAccessToken];
    [self loginWithPostData:[postData dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)loginWithPostData:(NSData *)postData {
    Reachability *rb = [Reachability reachabilityForInternetConnection];
    if (![rb isReachable])
    {
#if TARGET_OS_IPHONE
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network error" message:@"Unable to connect to the network. Please connect to a wireless network and try again." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        });
#endif
        return;
    }
    
    self.isAuthenticating = YES;
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod = @"POST";
    request.HTTPBody = postData;
    request.URL = [self authenticationURL];

    
#if DEBUG
    NSString *postDataString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
    NSLog(@"Sending request %@ to %@", postDataString, request.URL);
#endif
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
#if DEBUG
        NSLog(@"Login result: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif
        
        NSAssert([response isKindOfClass:[NSHTTPURLResponse class]], @"Assuming that the response is a HTTPURLResponse. Other protocols are currently not supported in TSNRESTSession.");
        
        self.isAuthenticating = NO;
        
        if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] > 204 || data.length == 0) {
            if (self.delegate) {
                if ([(NSHTTPURLResponse *)response statusCode] == 401) {
#if DEBUG
                    NSLog(@"Server refused login (401)");
#endif
                    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionLoginFailedWithError:)]) {
                        [self.delegate sessionLoginFailedWithError:error];
                    }
                    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionGotLoggedOut)]) {
                        [self.delegate sessionGotLoggedOut];
                    }
                }
                else if (self.flowDelegate && [self.flowDelegate respondsToSelector:@selector(sessionGotResponseWithError:completion:)]) {
                    [self.flowDelegate sessionGotResponseWithError:error completion:^{
                        [self.delegate sessionLoginFailedWithError:error];
                    }];
                } else {
                    [self.delegate sessionLoginFailedWithError:error];
                }
            }
            
            return;
        }
        else {
            NSError *jsonError = [[NSError alloc] init];
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if ([responseDict objectForKey:accessTokenKey]) {
                self.accessToken = [responseDict objectForKey:accessTokenKey];
            }
            if ([responseDict objectForKey:refreshTokenKey]) {
                self.refreshToken = [responseDict objectForKey:refreshTokenKey];
                
#if TARGET_OS_IPHONE
                if ([responseDict objectForKey:expiryKey]) {
                    if (self.expiryNotification)
                        [[UIApplication sharedApplication] cancelLocalNotification:self.expiryNotification];
                    NSInteger expiry = [[responseDict objectForKey:expiryKey] integerValue] *0.9+1;
                    self.expiryNotification = [[UILocalNotification alloc] init];
                    self.expiryNotification.userInfo = @{@"refreshToken":@1};
                    self.expiryNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:expiry];
                    [[UIApplication sharedApplication] scheduleLocalNotification:self.expiryNotification];
                }
#endif
            }
            
            NSNumber *userId = [responseDict objectForKey:userIdKey];
            
            [TSNRESTParser parseAndPersistDictionary:responseDict withCompletion:^{
                Class userClass = nil;
                if (self.delegate) {
                    userClass = [self.delegate sessionUserClass];
                }
                
                NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
                id user = nil;
                if (userId)
                    user = [userClass MR_findFirstByAttribute:idKey withValue:userId];
                else
                    user = [userClass MR_findFirst];
                
                
#if DEBUG
                NSLog(@"Login succeeded for user: %@", [user valueForKey:idKey]);
#endif
                
                if (self.flowDelegate && [self.flowDelegate respondsToSelector:@selector(sessionGotResponseWithUser:completion:)]) {
                    [self.flowDelegate sessionGotResponseWithUser:user completion:^{
                        [self finishLoggingInWithUserClass:userClass user:user response:response];
                    }];
                } else {
                    [self finishLoggingInWithUserClass:userClass user:user response:response];
                }
            }];
        }
    }];
    [task resume];
}

- (void)finishLoggingInWithUserClass:(Class)userClass user:(id)user response:(NSURLResponse *)response {
    if (userClass)
    {
        NSMutableDictionary *userDict = [[NSMutableDictionary alloc] init];
        [userDict setObject:NSStringFromClass(userClass) forKey:@"class"];
        if (user)
            [userDict setObject:user forKey:@"object"];
        if (response)
            [userDict setObject:response forKey:@"response"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LoginSucceeded" object:Nil userInfo:userDict];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionGotLoggedInWithUser:)]) {
        [self.delegate sessionGotLoggedInWithUser:user];
    }
}

#pragma mark - Logging out

- (void)logout {
    self.accessToken = nil;
    if (self.delegate && [self.delegate respondsToSelector:@selector(sessionGotLoggedOut)]) {
        [self.delegate sessionGotLoggedOut];
    }
}

- (void)logoutAndWhipeCredentials {
    [self logout];
    [self whipeCredentials];
}

- (void)whipeCredentials {
    self.accessToken = nil;
    self.refreshToken = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:userIdKey];
}


@end
