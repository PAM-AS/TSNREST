//
//  TSNRESTPoller.m
//  Pods
//
//  Created by Thomas Sunde Nielsen on 21.12.14.
//
//

#import "TSNRESTPoller.h"
#import "NSTimer+Blocks.h"

@interface TSNRESTPoller ()

@property (atomic, strong) NSMutableDictionary *pollers;

@end

@implementation TSNRESTPoller

- (NSTimer *)addPollerForKey:(NSString *)key poll:(void (^)())pollBlock interval:(NSTimeInterval)interval {
    [self removePollerForKey:key];
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval block:pollBlock repeats:YES];
    [self.pollers setObject:timer forKey:key];
    return nil;
}

- (void)removePollerForKey:(NSString *)key {
    NSTimer *timer = [self.pollers valueForKey:key];
    [timer invalidate];
    [self.pollers removeObjectForKey:key];
}

- (void)removeAllPollers {
    for (NSString *key in self.pollers) {
        [self removePollerForKey:key];
    }
}

- (NSTimer *)timerForKey:(NSString *)key {
    return [self.pollers objectForKey:key];
}

@end
