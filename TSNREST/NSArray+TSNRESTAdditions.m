//
//  NSArray+TSNRESTAdditions.m
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 12.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import "NSArray+TSNRESTAdditions.h"
#import "TSNRESTParser.h"

@implementation NSArray (TSNRESTAdditions)

- (void)faultGroup
{
    [self faultGroupWithSideloads:nil];
}

- (void)faultGroupWithSideloads:(NSArray *)sideloads
{
    NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self];
    SEL dirtyIdSelector = sel_registerName("dirty");
    
    if ([tempArray count] <= 0) // No objects to fault, array empty.
    {
        return;
    }
    
    for (id object in self)
    {
        if (![[object class] isSubclassOfClass:[NSManagedObject class]])
        {
#if DEBUG
            NSLog(@"%@ is not a subclass of NSManagedObject. Removing from faulting array.", NSStringFromClass([object class]));
#endif
            [tempArray removeObject:object];
        }
        else if (![object respondsToSelector:dirtyIdSelector])
        {
#if DEBUG
            NSLog(@"%@ is missing dirty key. Removing from faulting array.", NSStringFromClass([object class]));
#endif
            [tempArray removeObject:object];
        }
        else if (![[object valueForKey:@"dirty"] isEqualToNumber:@2])
        {
#if DEBUG
            NSLog(@"%@ doesn't need faulting (dirty is not 2). Removing from faulting array.", [object valueForKey:@"systemId"]);
#endif
            [tempArray removeObject:object];
        }
    }
    
    if ([tempArray count] <= 0)
    {
#if DEBUG
        NSLog(@"No faultable NSManagedObjects in array. Returning.");
#endif
        return;
    }
    else
    {
#if DEBUG
        NSLog(@"Faulting %lu objects of type %@", (unsigned long)tempArray.count, NSStringFromClass([tempArray.firstObject class]));
#endif
    }
    
    [tempArray refreshGroupWithSideloads:sideloads];
}

- (void)refreshGroup
{
    [self refreshGroupWithSideloads:nil];
}


- (void)refreshGroupWithSideloads:(NSArray *)sideloads
{
    if (self.count == 0)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableString *ids = [[NSMutableString alloc] initWithString:@"?id="];
        
        SEL systemidSelector = sel_registerName("systemId");
        for (id object in self)
        {
            if ([object respondsToSelector:systemidSelector])
            {
                if (![[ids substringFromIndex:ids.length-1] isEqualToString:@"="])
                    [ids appendString:@","];
                [ids appendString:[NSString stringWithFormat:@"%@", [object valueForKey:@"systemId"]]];
            }
        }
        
        TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[[self objectAtIndex:0] class]];
        if (!map)
        {
#if DEBUG
            NSLog(@"No map for %@, can't fault.", NSStringFromClass([[self objectAtIndex:0] class]));
#endif
            return;
        }
        
        NSString *url = [[(NSString *)[[TSNRESTManager sharedManager] baseURL] stringByAppendingPathComponent:map.serverPath] stringByAppendingString:ids];
        
        if (sideloads && sideloads.count > 0)
        {
            NSMutableString *sideloadString = [[NSMutableString alloc] initWithString:@"&include="];
            for (NSString *string in sideloads)
            {
                if (![[sideloadString substringFromIndex:sideloadString.length-1] isEqualToString:@"="])
                    [sideloadString appendString:@","];
                [sideloadString appendString:string];
            }
            if (sideloads)
                url = [url stringByAppendingString:sideloadString];
        }
        
#if DEBUG
        NSLog(@"Refreshing group of %@ with URL: %@", NSStringFromClass([map classToMap]), url);
#endif
        
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [[TSNRESTManager sharedManager] handleResponse:response
                                                  withData:data
                                                     error:error
                                                    object:nil
                                                completion:nil];
        }];
        [task resume];
    });
}

- (void)saveAndPersistContainedNSManagedObjects
{
    [self saveAndPersistContainedNSManagedObjectsWithSuccess:nil failure:nil finally:nil];
}

- (void)saveAndPersistContainedNSManagedObjectsWithSuccess:(void (^)(id object))successBlock failure:(void (^)(id object))failureBlock finally:(void (^)(id object))finallyBlock
{
    if (self.count < 1)
    {
#if DEBUG
        NSLog(@"Tried to persist empty array. returning with failure.");
#endif
        if (failureBlock)
            failureBlock(self);
        if (finallyBlock)
            finallyBlock(self);
        return;
    }
    
    __weak typeof(self) _weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *doneYet = [[NSMutableArray alloc] initWithCapacity:_weakSelf.count];
        NSMutableArray *successful = [[NSMutableArray alloc] initWithCapacity:_weakSelf.count];
        
        for (id object in _weakSelf)
        {
            if ([object isKindOfClass:[NSManagedObject class]])
            {
                [doneYet addObject:[NSNumber numberWithBool:NO]];
                [successful addObject:[NSNumber numberWithBool:NO]];
            }
        }
        
        for (id object in _weakSelf)
        {
            if (![object isKindOfClass:[NSManagedObject class]])
                continue;
            
            NSUInteger index = [_weakSelf indexOfObject:object];
            [object saveAndPersistWithSuccess:^(id object) {
                [successful replaceObjectAtIndex:index withObject:@YES];
            } failure:^(id object) {
                [successful replaceObjectAtIndex:index withObject:@NO];
            } finally:^(id object) {
                [doneYet replaceObjectAtIndex:index withObject:@YES];
                if (![doneYet containsObject:@NO])
                {
                    BOOL wasSuccess = ![successful containsObject:@NO];
#if DEBUG
                    NSLog(@"Updated %lu objects, with success %i", (unsigned long)_weakSelf.count, wasSuccess);
#endif
                    if (wasSuccess && successBlock)
                        successBlock(_weakSelf);
                    else if (!wasSuccess && failureBlock)
                        failureBlock(_weakSelf);
                    if (finallyBlock)
                        finallyBlock(_weakSelf);
                }
            }];
        }
    });
}

@end
