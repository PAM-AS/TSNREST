//
//  TSNRESTPoller.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 21.12.14.
//
//

#import <Foundation/Foundation.h>

@interface TSNRESTPoller : NSObject

- (NSTimer *)addPollerForKey:(NSString *)key poll:(void (^)())pollBlock interval:(NSTimeInterval)interval;
- (void)removePollerForKey:(NSString *)key;
- (NSTimer *)timerForKey:(NSString *)key;

@end
