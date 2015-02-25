//
//  NSData+AuthenticatedDownload.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 25.02.15.
//
//

#import <Foundation/Foundation.h>

@interface NSData (AuthenticatedDownload)

/*
 Synchronous method comparable to dataWithContentsOfURL:.
 */
+ (NSData *)dataWithContentsOfURL:(NSURL *)url authenticated:(BOOL)authenticated;

@end
