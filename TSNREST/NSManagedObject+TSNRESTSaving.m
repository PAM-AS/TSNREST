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
    
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_context];
    __block NSManagedObject *object = nil;
    __block BOOL isDeleted = false;
    [localContext performBlockAndWait:^{
        object = [self MR_inContext:localContext];
        isDeleted = object.isDeleted;
    }];
    
    [[TSNRESTManager sharedManager] addSelfSavingObject:self];
    [object.managedObjectContext MR_saveToPersistentStoreAndWait]; // Catch changes made externally
    
    if (isDeleted)
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
    
    
    
    if (object.inFlight)
    {
#if DEBUG
        NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
        NSLog(@"Skipping save of %@ %@ because object already is in flight.", NSStringFromClass([self class]), [self valueForKey:idKey]);
#endif
        __block NSManagedObject *selfObject = self;
#warning Find a way to not call the successBlock here. It's not technically correct.
        if (successBlock)
            successBlock(selfObject);
        if (finallyBlock)
            finallyBlock(selfObject);
        [[TSNRESTManager sharedManager] removeSelfSavingObject:self];
        return;
    }
    
    __block BOOL isValid = YES;
    [localContext performBlockAndWait:^{
        isValid = object.isValid;
    }];
    
    if (!isValid)
    {
#if DEBUG
        NSLog(@"Skipping object of type %@ because it's invalid.", NSStringFromClass([self class]));
        NSLog(@"%@", self);
#endif
        NSManagedObject *selfObject = self;
        if (failureBlock)
            failureBlock(selfObject);
        if (finallyBlock)
            finallyBlock(selfObject);
        [[TSNRESTManager sharedManager] removeSelfSavingObject:self];
        return;
    }
    
    object.inFlight = YES;
    
    __block NSString *uuid = nil;
    
    if ([self respondsToSelector:NSSelectorFromString(@"uuid")])
    {
        [localContext performBlockAndWait:^{
            uuid = [object valueForKey:@"uuid"];
        }];
        
        if (!uuid)
        {
            __block NSManagedObject *object = self;
            [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                [[object MR_inContext:localContext] setValue:[[NSUUID UUID] UUIDString] forKey:@"uuid"];
            }];
        }
    }
    
    
    __block NSManagedObject *selfObject = self;
    __block NSURLRequest *request = nil;
    [localContext performBlockAndWait:^{
        request = [NSURLRequest requestForObject:object optionalKeys:optionalKeys];
    }];
    NSURLSessionDataTask *dataTask = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([object respondsToSelector:NSSelectorFromString(@"dirty")]) {
            [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                [[selfObject MR_inContext:localContext] setValue:@0 forKey:@"dirty"];
            }];
        }
        
#if DEBUG
        NSString *resultString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"Saved data, got response: %@", resultString);
        
        NSLog(@"Status code: %li", [(NSHTTPURLResponse *)response statusCode]);
#endif
#if AIRWATCH
        NSString *resultString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"Saved data, got response: %@", resultString);
        
        NSLog(@"Status code: %li", [(NSHTTPURLResponse *)response statusCode]);
#endif
        
        NSError *jsonError = [[NSError alloc] init];
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        NSLog(@"Firing parser from TSNRESTSaving");
        [TSNRESTParser parseAndPersistDictionary:jsonDict withCompletion:^{
            if (successBlock)
                successBlock(selfObject);
            if (finallyBlock)
                finallyBlock(selfObject);
        } forObject:object];
    } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
        if (statusCode == 404) {
            [object deleteFromServer];
            if (finallyBlock)
                finallyBlock(nil);
        }
        else {
            if (failureBlock)
                failureBlock(selfObject);
            if (finallyBlock)
                finallyBlock(selfObject);
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
        selfObject.inFlight = NO;
        [[TSNRESTManager sharedManager] removeSelfSavingObject:selfObject];
    } parseResult:NO]; // We trigger parsing ourselves so we can pass the object.
    
    [dataTask resume];
}

@end
