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

- (void)saveAndPersistWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock optionalKeys:(NSArray *)optionalKeys
{
    // Save any external changes
    [self.managedObjectContext MR_saveToPersistentStoreAndWait];
    
    // Have a weak reference to self that we can use further on when we need to reference the original object, not the in-context copy
    NSManagedObject __weak *weakSelf = self;
    
    // Create a new context for the save operation
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_context];
    [localContext performBlock:^{
        NSManagedObject *object = [self MR_inContext:localContext];
        
        if (object.isDeleted) {
#if DEBUG
            NSLog(@"Skipping saving of product, since it has been deleted.");
#endif
            if (failureBlock)
                failureBlock(nil);
            if (finallyBlock)
                finallyBlock(nil);
            return;
        }
        
        if (weakSelf.inFlight) {
#if DEBUG
            NSString *idKey = [(TSNRESTManagerConfiguration *)[[TSNRESTManager sharedManager] configuration] localIdName];
            NSLog(@"Skipping save of %@ %@ because object already is in flight.", NSStringFromClass([self class]), [self valueForKey:idKey]);
#endif
            
#warning Find a way to not call the successBlock here. It's not technically correct. But some other part of TSNREST may currently need it
            dispatch_async(dispatch_get_main_queue(), ^{
                NSManagedObject *mainThreadObject = [object MR_inContext:[NSManagedObjectContext MR_defaultContext]];
                if (successBlock)
                    successBlock(mainThreadObject);
                if (finallyBlock)
                    finallyBlock(mainThreadObject);
            });
            return;
        }
        
        if (!object.isValid) {
#if DEBUG
            NSLog(@"Skipping object of type %@ because it's invalid.", NSStringFromClass([object class]));
            NSLog(@"%@", object);
#endif
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSManagedObject *mainThreadObject = [object MR_inContext:[NSManagedObjectContext MR_defaultContext]];
                if (failureBlock)
                    failureBlock(mainThreadObject);
                if (finallyBlock)
                    finallyBlock(mainThreadObject);
            });
            return;
        }
        
        weakSelf.inFlight = YES;
        
        if ([object respondsToSelector:NSSelectorFromString(@"uuid")])
        {
            if (![object valueForKey:@"uuid"]) {
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    [[object MR_inContext:localContext] setValue:[[NSUUID UUID] UUIDString] forKey:@"uuid"];
                }];
            }
        }
        
        NSURLRequest *request = [NSURLRequest requestForObject:object optionalKeys:optionalKeys];
       
        NSURLSessionDataTask *dataTask = [NSURLSessionDataTask dataTaskWithRequest:request success:^(NSData *data, NSURLResponse *response, NSError *error) {
            
            // Reset any dirty value, we've got latest from the web
            if ([object respondsToSelector:NSSelectorFromString(@"dirty")]) {
                [MagicalRecord saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
                    [[object MR_inContext:localContext] setValue:@0 forKey:@"dirty"];
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSManagedObject *mainThreadObject = [object MR_inContext:[NSManagedObjectContext MR_defaultContext]];
                    if (successBlock)
                        successBlock(mainThreadObject);
                    if (finallyBlock)
                        finallyBlock(mainThreadObject);
                });
            } forObject:object];
        } failure:^(NSData *data, NSURLResponse *response, NSError *error, NSInteger statusCode) {
            if (statusCode == 404) {
                [object deleteFromServer];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (finallyBlock)
                        finallyBlock(nil);
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSManagedObject *mainThreadObject = [object MR_inContext:[NSManagedObjectContext MR_defaultContext]];
                    if (failureBlock)
                        failureBlock(mainThreadObject);
                    if (finallyBlock)
                        finallyBlock(mainThreadObject);
                });
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
            weakSelf.inFlight = NO;
        } parseResult:NO]; // We trigger parsing ourselves so we can pass the object into the parser.
        
        [dataTask resume];
    }];
}

@end
