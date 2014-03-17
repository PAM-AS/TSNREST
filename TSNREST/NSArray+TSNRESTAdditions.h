//
//  NSArray+TSNRESTAdditions.h
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 12.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "CoreData+MagicalRecord.h"

@interface NSArray (TSNRESTAdditions)

- (void)faultGroup;
- (void)faultGroupWithSideloads:(NSArray *)sideloads;
- (void)refreshGroup;
- (void)refreshGroupWithSideloads:(NSArray *)sideloads;
- (void)persistContainedNSManagedObjects;

@end
