//
//  NSManagedObject+TSNRESTSaving.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 22.11.14.
//
//

#import "NSManagedObject+TSNRESTSaving.h"
#import "NSManagedObject+TSNRESTValidation.h"
#import "TSNRESTManager.h"

@implementation NSManagedObject (TSNRESTSaving)

- (void)saveAndPersist
{
    [self saveAndPersistWithSuccess:nil failure:nil finally:nil];
}

- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock
{
    [self saveAndPersistWithSuccess:successBlock failure:failureBlock finally:nil];
}

- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock
{
    [self saveAndPersistWithSuccess:successBlock failure:failureBlock finally:finallyBlock optionalKeys:nil];
}

- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock optionalKeys:(NSArray *)optionalKeys
{
    dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
        // Catch changes made externally
        [self.managedObjectContext MR_saveToPersistentStoreAndWait];
        
        if (self.isDeleted || [self hasBeenDeleted])
        {
#if DEBUG
            NSLog(@"Skipping saving of product, since it has been deleted.");
#endif
            if (failureBlock)
                failureBlock(nil);
            if (finallyBlock)
                finallyBlock(nil);
            return;
        }
        
        if (self.inFlight)
        {
#if DEBUG
            NSLog(@"Skipping save of %@ %@ because object already is in flight.", NSStringFromClass([self class]), [self valueForKey:@"systemId"]);
#endif
            if (successBlock)
                successBlock(self);
            if (finallyBlock)
                finallyBlock(self);
            return;
        }
        self.inFlight = YES;
        
        if (!self.isValid)
        {
            if (failureBlock)
                failureBlock(nil);
            if (finallyBlock)
                finallyBlock(nil);
            return;
        }
        
        NSURLSession *currentSession = [NSURLSession sharedSession];
        
        if ([self respondsToSelector:NSSelectorFromString(@"uuid")])
        {
            if (![self valueForKey:@"uuid"])
            {
                [self setValue:[[NSUUID UUID] UUIDString] forKey:@"uuid"];
                [self.managedObjectContext MR_saveOnlySelfAndWait];
            }
        }
        
        [[TSNRESTManager sharedManager] startLoading:@"persistWithCompletion:session:"];
        NSURLRequest *request = [[TSNRESTManager sharedManager] requestForObject:self optionalKeys:optionalKeys];
        NSURLSessionDataTask *dataTask = [currentSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [[TSNRESTManager sharedManager] handleResponse:response withData:data error:error object:self completion:^(id object, BOOL success) {
                [[TSNRESTManager sharedManager] endLoading:@"persistWithCompletion:session:"];
                self.inFlight = NO;
                [self.managedObjectContext MR_saveToPersistentStoreWithCompletion:nil];
                if (success && successBlock)
                {
                    successBlock(self);
                }
                else if (failureBlock && !success)
                {
                    failureBlock(self);
                }
                if (finallyBlock)
                    finallyBlock(self);
            }];
#if DEBUG
            if (error)
            {
                NSLog(@"Data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                NSLog(@"Response: %@", response);
                NSLog(@"Error: %@", [error userInfo]);
            }
#endif
        }];
        [dataTask resume];
        
    });
}

@end
