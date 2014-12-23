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

@end
