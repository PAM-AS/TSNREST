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
#import "TSNRESTParser.h"
#import "NSURLRequest+TSNRESTConveniences.h"

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

- (void)saveAndPersistWithSuccess:(void (^)(id object))yayBlock failure:(void (^)(id object))failBlock finally:(void (^)(id object))doneBlock optionalKeys:(NSArray *)optionalKeys
{
    __block void(^successBlock)(id) = yayBlock;
    __block void(^failureBlock)(id) = failBlock;
    __block void(^finallyBlock)(id) = doneBlock;
    __block NSManagedObject *object = self;
    
    [[TSNRESTManager sharedManager] addSelfSavingObject:object];
    [object.managedObjectContext MR_saveToPersistentStoreAndWait]; // Catch changes made externally
    
    dispatch_async([[TSNRESTManager sharedManager] serialQueue], ^{
        if (object.isDeleted)
        {
#if DEBUG
            NSLog(@"Skipping saving of product, since it has been deleted.");
#endif
            if (failureBlock)
                failureBlock(nil);
            if (finallyBlock)
                finallyBlock(nil);
            [[TSNRESTManager sharedManager] removeSelfSavingObject:object];
            return;
        }
        
        if (object.inFlight)
        {
#if DEBUG
            NSLog(@"Skipping save of %@ %@ because object already is in flight.", NSStringFromClass([object class]), [object valueForKey:@"systemId"]);
#endif
#warning Find a way to not call the successBlock here. It's not technically correct.
            if (successBlock)
                successBlock(object);
            if (finallyBlock)
                finallyBlock(object);
            [[TSNRESTManager sharedManager] removeSelfSavingObject:object];
            return;
        }
        
        if (!object.isValid)
        {
            if (failureBlock)
                failureBlock(object);
            if (finallyBlock)
                finallyBlock(object);
            [[TSNRESTManager sharedManager] removeSelfSavingObject:object];
            return;
        }
        
        object.inFlight = YES;
        
        if ([object respondsToSelector:NSSelectorFromString(@"uuid")])
        {
            if (![object valueForKey:@"uuid"])
            {
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    [[object MR_inContext:localContext] setValue:[[NSUUID UUID] UUIDString] forKey:@"uuid"];
                }];
            }
        }
        
        NSURLRequest *request = [NSURLRequest requestForObject:object optionalKeys:optionalKeys];
        NSURLSessionDataTask *dataTask = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
            if ([object respondsToSelector:NSSelectorFromString(@"dirty")]) {
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    [[object MR_inContext:localContext] setValue:@0 forKey:@"dirty"];
                }];
            }
            
            NSError *jsonError = [[NSError alloc] init];
            NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            [TSNRESTParser parseAndPersistDictionary:jsonDict withCompletion:^{
                if (successBlock)
                    successBlock(object);
                if (finallyBlock)
                    finallyBlock(object);
            } forObject:object];
        } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
            if (statusCode == 404) {
                [object deleteFromServer];
                if (finallyBlock)
                    finallyBlock(nil);
            }
            else {
                if (failureBlock)
                    failureBlock(object);
                if (finallyBlock)
                    finallyBlock(object);
            }
            
#if DEBUG
            if (error)
            {
                NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Data: %@", dataString);
                dataString = nil;
                NSLog(@"Response: %@", response);
                NSLog(@"Error: %@", [error userInfo]);
            }
#endif
            
        } finally:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSLog(@"No longer in flight.");
            object.inFlight = NO;
            [[TSNRESTManager sharedManager] removeSelfSavingObject:object];
        }];
        
        [dataTask resume];
    });
}

@end
