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
    
    
    [[TSNRESTManager sharedManager] addSelfSavingObject:self];
    [self.managedObjectContext MR_saveToPersistentStoreAndWait]; // Catch changes made externally
    
    if (self.isDeleted)
    {
#if DEBUG
        NSLog(@"Skipping saving of product, since it has been deleted.");
#endif
        if (failureBlock)
            failureBlock(nil);
        if (finallyBlock)
            finallyBlock(nil);
        [[TSNRESTManager sharedManager] removeSelfSavingObject:self];
        return;
    }
    
    
    
    if (self.inFlight)
    {
#if DEBUG
        NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
        NSLog(@"Skipping save of %@ %@ because object already is in flight.", NSStringFromClass([self class]), [self valueForKey:idKey]);
#endif
        __block NSManagedObject *object = self;
#warning Find a way to not call the successBlock here. It's not technically correct.
        if (successBlock)
            successBlock(object);
        if (finallyBlock)
            finallyBlock(object);
        [[TSNRESTManager sharedManager] removeSelfSavingObject:self];
        return;
    }
    
    if (!self.isValid)
    {
#if DEBUG
        NSLog(@"Skipping object of type %@ because it's invalid.", NSStringFromClass([self class]));
#endif
        __block NSManagedObject *object = self;
        if (failureBlock)
            failureBlock(object);
        if (finallyBlock)
            finallyBlock(object);
        [[TSNRESTManager sharedManager] removeSelfSavingObject:self];
        return;
    }
    
    self.inFlight = YES;
    
    if ([self respondsToSelector:NSSelectorFromString(@"uuid")])
    {
        if (![self valueForKey:@"uuid"])
        {
            __block NSManagedObject *object = self;
            [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                [[object MR_inContext:localContext] setValue:[[NSUUID UUID] UUIDString] forKey:@"uuid"];
            }];
        }
    }
    
    
    __block NSManagedObject *object = self;
    NSURLRequest *request = [NSURLRequest requestForObject:object optionalKeys:optionalKeys];
    NSURLSessionDataTask *dataTask = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([object respondsToSelector:NSSelectorFromString(@"dirty")]) {
            [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                [[object MR_inContext:localContext] setValue:@0 forKey:@"dirty"];
            }];
        }
        
        NSError *jsonError = [[NSError alloc] init];
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        NSLog(@"Firing parser from TSNRESTSaving");
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
    } parseResult:NO]; // We trigger parsing ourselves so we can pass the object.
    
    [dataTask resume];
}

@end
