//
//  TSNRESTManagerConfiguration.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 23.12.14.
//
//

#import <Foundation/Foundation.h>

@interface TSNRESTManagerConfiguration : NSObject

@property (nonatomic, strong) NSString *localIdName; // default: systemId
@property (nonatomic, strong) NSURL *baseURL;
@property (nonatomic, strong) Class userClass;

/*
 Optimizing
 
 You can add a set of keys here that will trigger parsing to be skipped,
 if the value is equal on the server and in Core Data. Typical use cases
 are timestamps for last update, etc.
 */
@property (nonatomic) BOOL shouldOptimizeBySkipping;
@property (nonatomic) NSString *optimizableKey;

@end
