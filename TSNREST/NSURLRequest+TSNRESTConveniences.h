//
//  NSURLRequest+TSNRESTConveniences.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 02.12.14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface NSURLRequest (TSNRESTConveniences)

+ (NSURLRequest *)requestForObject:(NSManagedObject *)object;
+ (NSURLRequest *)requestForObject:(NSManagedObject *)object optionalKeys:(NSArray *)optionalKeys;
+ (NSURLRequest *)requestForObject:(NSManagedObject *)object optionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys;
+ (NSURLRequest *)requestForClass:(Class)class ids:(NSArray *)ids;
+ (NSURLRequest *)requestForClass:(Class)class query:(NSString *)query;

@end
