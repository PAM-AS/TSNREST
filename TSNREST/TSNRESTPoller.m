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

- (id)init {
    self = [super init];
    self.pollers = [NSMutableDictionary new];
    return self;
}

- (NSTimer *)addPollerForKey:(NSString *)key poll:(void (^)())pollBlock interval:(NSTimeInterval)interval {
    [self removePollerForKey:key];
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval block:pollBlock repeats:YES];
    [self.pollers setObject:timer forKey:key];
    return timer;
}

- (void)removePollerForKey:(NSString *)key {
    NSTimer *timer = [self.pollers valueForKey:key];
    [timer invalidate];
    [self.pollers removeObjectForKey:key];
}

- (void)removeAllPollers {
    [self.pollers removeAllObjects];
}

- (NSTimer *)timerForKey:(NSString *)key {
    return [self.pollers objectForKey:key];
}

- (NSUInteger)countOfActiveTimers {
    return self.pollers.count;
}

@end
