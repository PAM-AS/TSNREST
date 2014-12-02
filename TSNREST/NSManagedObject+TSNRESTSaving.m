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
#import "NSURLSessionDataTask+TSNRESTDataTask.h"
#import "NSManagedObject+TSNRESTDeletion.h"
#import "MagicalRecord.h"

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
        
        if (self.isDeleted)
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
#warning Find a way to not call the successBlock here. It's not technically correct.
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
        
        if ([self respondsToSelector:NSSelectorFromString(@"uuid")])
        {
            if (![self valueForKey:@"uuid"])
            {
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    [[self MR_inContext:localContext] setValue:[[NSUUID UUID] UUIDString] forKey:@"uuid"];
                }];
            }
        }
        
        NSURLRequest *request = [[TSNRESTManager sharedManager] requestForObject:self optionalKeys:optionalKeys];
        NSURLSessionDataTask *dataTask = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
            if ([self respondsToSelector:NSSelectorFromString(@"dirty")]) {
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    [[self MR_inContext:localContext] setValue:@0 forKey:@"dirty"];
                }];
            }
            [self.managedObjectContext MR_saveOnlySelfAndWait];
            if (successBlock)
                successBlock(self);
            if (finallyBlock)
                finallyBlock(self);
        } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
            if (statusCode == 404) {
                [self deleteFromServer];
                if (finallyBlock)
                    finallyBlock(nil);
            }
            else {
                if (failureBlock)
                    failureBlock(self);
                if (finallyBlock)
                    finallyBlock(self);
            }
            
#if DEBUG
            if (error)
            {
                NSLog(@"Data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                NSLog(@"Response: %@", response);
                NSLog(@"Error: %@", [error userInfo]);
            }
#endif
            
        } finally:nil];

        [dataTask resume];
        
    });
}

@end
