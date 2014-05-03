//
//  TSNRESTLogin.m
//  todomvc
//
//  Created by Thomas Sunde Nielsen on 09.12.13.
//  Copyright (c) 2013 Thomas Sunde Nielsen. All rights reserved.
//

#import "TSNRESTLogin.h"
#import "TSNRESTParser.h"
#import "Reachability.h"

@implementation TSNRESTLogin

+ (void)loginWithDefaultRefreshTokenAndUserClass:(Class)userClass url:(NSString *)url
{
    [self loginWithDefaultRefreshTokenAndUserClass:userClass url:url completion:nil];
}


+ (void)loginWithDefaultRefreshTokenAndUserClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion
{
    [self loginWithRefreshToken:[[NSUserDefaults standardUserDefaults] objectForKey:@"refresh_token"] userClass:userClass url:url completion:completion];
}

+ (void)loginWithRefreshToken:(NSString *)token userClass:(Class)userClass url:(NSString *)url
{
    [self loginWithRefreshToken:token userClass:userClass url:url completion:nil];
}

+ (void)loginWithRefreshToken:(NSString *)token userClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion
{
    NSString *postData = [NSString stringWithFormat:@"grant_type=refresh_token&refresh_token=%@", token];
    [TSNRESTLogin loginWithPostData:postData userClass:userClass url:url completion:completion];
}

+ (void)loginWithUser:(NSString *)user password:(NSString *)password userClass:(Class)userClass url:(NSString *)url
{
    [self loginWithUser:user password:password userClass:userClass url:url completion:nil];
}

+ (void)loginWithUser:(NSString *)user password:(NSString *)password userClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion
{
    NSString *postData = [NSString stringWithFormat:@"username_or_email=%@&password=%@&grant_type=password", user, password];
    
    [TSNRESTLogin loginWithPostData:postData userClass:userClass url:url completion:completion];
}

+ (void)loginWithFacebookId:(NSString *)fbId accessToken:(NSString *)accessToken userClass:(Class)userClass url:(NSString *)url
{
    [self loginWithFacebookId:fbId accessToken:accessToken userClass:userClass url:url completion:nil];
}

+ (void)loginWithFacebookId:(NSString *)fbId accessToken:(NSString *)accessToken userClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion
{
    NSString *postData = [NSString stringWithFormat:@"fb_user_id=%@&fb_access_token=%@&grant_type=facebook_token", fbId, accessToken];
    
    [TSNRESTLogin loginWithPostData:postData userClass:userClass url:url completion:completion];
}

+ (void)loginWithPostData:(NSString *)postData userClass:(Class)userClass url:(NSString *)url completion:(void (^)(id object, BOOL success))completion
{
    Reachability *rb = [Reachability reachabilityForInternetConnection];
    if (![rb isReachable])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Nettverksproblem" message:@"Du ser ikke ut til å være tilkoblet et nettverk. Koble til et trådløst nettverk og prøv igjen" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        });
        completion(nil, NO);
        return;
    }
    
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[postData dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSLog(@"Sending request %@ to %@", postData, url);
    
    [request setURL:[NSURL URLWithString:url]];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSLog(@"Login result: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] > 204 || [data length] == 0)
        {
            NSLog(@"Login failed. %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            if (completion)
                completion(nil, NO);
        }
        else
        {
            NSLog(@"Login Succeeded. Proceeding to create user object. %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            [[TSNRESTManager sharedManager] runQueuedRequests];
            NSDictionary *dataDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            
            if ([dataDict objectForKey:@"access_token"])
            {
                [[TSNRESTManager sharedManager] setGlobalHeader:[NSString stringWithFormat:@"Bearer %@", [dataDict objectForKey:@"access_token"]] forKey:@"Authorization"];
                [[NSUserDefaults standardUserDefaults] setObject:[dataDict objectForKey:@"access_token"] forKey:@"access_token"];
            }
            if ([dataDict objectForKey:@"refresh_token"])
            {
                [[NSUserDefaults standardUserDefaults] setObject:[dataDict objectForKey:@"refresh_token"] forKey:@"refresh_token"];
                if ([dataDict objectForKey:@"expires_in"])
                {
                    [[UIApplication sharedApplication] cancelAllLocalNotifications];
                    NSInteger expiry = [[dataDict objectForKey:@"expires_in"] integerValue] * 0.9+1;
                    UILocalNotification *notification = [[UILocalNotification alloc] init];
                    notification.userInfo = @{@"refreshToken":@1};
                    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:expiry];
                    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
                }
            }
            
            NSNumber *userId = nil;
            if ([dataDict objectForKey:@"user_id"])
                userId = [dataDict objectForKey:@"user_id"];
            
            [TSNRESTParser parseAndPersistDictionary:dataDict withCompletion:^{
                // + (id) findFirstByAttribute:(NSString *)attribute withValue:(id)searchValue;
                id user = nil;
                if (userId)
                    user = [userClass findFirstByAttribute:@"systemId" withValue:userId];
                else
                    user = [userClass findFirst];
                
                NSLog(@"Login succeeded for user: %@", [user valueForKey:@"systemId"]);
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
                if (completion && user)
                    completion(user, YES);
                else if (completion)
                    completion(dataDict, YES);
            }];

            /*
            if ([user respondsToSelector:NSSelectorFromString(@"persistWithCompletion:")])
            {
                // Equal to [user performSelector:NSSelectorFromString(@"persist") withObject:nil];
                // But without the warning (ARC doesn't think it's safe otherwise).
                // http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
                SEL selector = NSSelectorFromString(@"persistWithCompletion:");
                IMP imp = [user methodForSelector:selector];
                void (*func)(id, SEL, id) = (void *)imp;
                func(user, selector, completion);
            }
             */
         
            
        }
    }];
    [dataTask resume];
}

@end
