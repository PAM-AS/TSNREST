//
//  NSObject+PropertyClass.h
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 03.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (PropertyClass)

-(Class)classOfPropertyNamed:(NSString*) propertyName;

@end
