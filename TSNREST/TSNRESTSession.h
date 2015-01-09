//
//  TSNRESTSession.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 05.01.15.
//
//

#import <Foundation/Foundation.h>

@protocol TSNRESTSessionDelegate <NSObject>

@required
- (Class)sessionUserClass; // What class should the user get mapped to? Return nil if you don't have a user class.

@optional
// Callbacks for when the session status changes.
- (void)sessionStartedLoggingIn;
- (void)sessionLoginFailedWithError:(NSError *)error;
- (void)sessionGotLoggedInWithUser:(id)user; // returns a object of the class you pass to sessionUserClass.
- (void)sessionGotLoggedOut;

@end

// This protocol is ment to hold back the callbacks to the usual delegate during login.
@protocol TSNRESTSessionLoginFlowDelegate <NSObject>

@optional
- (void)sessionGotResponseWithUser:(id)user completion:(void (^)())completion;
- (void)sessionGotResponseWithError:(NSError *)error completion:(void (^)())completion;

@end

@interface TSNRESTSession : NSObject

@property (nonatomic, weak) id <TSNRESTSessionDelegate> delegate;
@property (nonatomic, weak) id <TSNRESTSessionLoginFlowDelegate> flowDelegate;
@property (nonatomic) BOOL isLoggedIn;
@property (nonatomic) BOOL isAuthenticating;
@property (nonatomic, strong) NSString *authPath; // Appended to the RESTManagers baseURL.
@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSString *refreshToken;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong, readonly) NSString *userId;
@property (nonatomic) BOOL saveTokensToNSUserDefaults; // default YES

- (NSDictionary *)addHeader:(NSString *)header forKey:(NSString *)key; // Returns the new header dictionary.

- (void)loginWithDefaultInfo; // Assumes delegate is set, as well as authPath and accessToken or refreshToken.
- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password;

- (void)logout;
- (void)logoutAndWhipeCredentials;
- (void)whipeCredentials;

@end
