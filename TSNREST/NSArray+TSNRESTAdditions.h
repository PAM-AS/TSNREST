//
//  NSArray+TSNRESTAdditions.h
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 12.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#define MR_ENABLE_ACTIVE_RECORD_LOGGING 0
#define MR_SHORTHAND 1

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
