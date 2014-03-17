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
    
    if ([tempArray count] <= 0)
    {
        NSLog(@"Array is empty. Can't fault nothin'. Returning.");
        return;
    }
    
    for (id object in self)
    {
        if (![[object class] isSubclassOfClass:[NSManagedObject class]])
        {
            NSLog(@"%@ is not a subclass of NSManagedObject. Removing.", NSStringFromClass([object class]));
            [tempArray removeObject:object];
        }
        else if (![object respondsToSelector:dirtyIdSelector])
        {
            NSLog(@"%@ is missing dirty key. Removing.", NSStringFromClass([object class]));
            [tempArray removeObject:object];
        }
        else if (![[object valueForKey:@"dirty"] isEqualToNumber:@2])
        {
            NSLog(@"%@ doesn't need faulting (dirty is not 2). Removing.", [object valueForKey:@"systemId"]);
            [tempArray removeObject:object];
        }
    }
    
    if ([tempArray count] <= 0)
    {
        NSLog(@"No faultable NSManagedObjects in array. Returning.");
        return;
    }
    
    [tempArray refreshGroupWithSideloads:sideloads];
}

- (void)refreshGroup
{
    [self refreshGroupWithSideloads:nil];
}

- (void)refreshGroupWithSideloads:(NSArray *)sideloads
{
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
    
    NSMutableString *sideloadString = [[NSMutableString alloc] initWithString:@"&_sl="];
    for (NSString *string in sideloads)
    {
        if (![[sideloadString substringFromIndex:sideloadString.length-1] isEqualToString:@"="])
            [sideloadString appendString:@","];
        [sideloadString appendString:string];
    }

    TSNRESTObjectMap *map = [[TSNRESTManager sharedManager] objectMapForClass:[[self objectAtIndex:0] class]];
    if (!map)
    {
        NSLog(@"No map for %@, can't fault.", NSStringFromClass([[self objectAtIndex:0] class]));
        return;
    }
    
    NSString *url = [[(NSString *)[[TSNRESTManager sharedManager] baseURL] stringByAppendingPathComponent:map.serverPath] stringByAppendingString:ids];
    if (sideloads)
        url = [url stringByAppendingString:sideloadString];
    
    NSLog(@"Refreshing group with URL: %@", url);
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSLog(@"Got a dict back, transmitting it to our parser");
        [TSNRESTParser parseAndPersistDictionary:dict];
    }];
    [task resume];
}

- (void)persistContainedNSManagedObjects
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"startLoadingAnimation" object:nil];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (id object in self)
        {
            if (![object isKindOfClass:[NSManagedObject class]])
                continue;
            NSLog(@"Got %@", [object valueForKey:@"systemId"]);
            NSURLRequest *request = [[TSNRESTManager sharedManager] requestForObject:object];
            NSURLResponse *response = [[NSURLResponse alloc] init];
            NSError *error = [[NSError alloc] init];
            NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            // Only stop animating on last object.
            if (object != [self lastObject])
                [[TSNRESTManager sharedManager] handleResponse:response withData:result error:error object:object completion:nil];
            else
                [[TSNRESTManager sharedManager] handleResponse:response withData:result error:error object:object completion:^(id object, BOOL success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"stopLoadingAnimation" object:nil];
                    });
                }];
            NSLog(@"Still got %@", [object valueForKey:@"systemId"]);
        }
    });
}

@end
