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
 @param url The url you wish to fetch from.
 @param authenticated Wether to add authentication headers or not.
 @returns the data found at the specified URL
 */
+ (NSData *)dataWithContentsOfURL:(NSURL *)url authenticated:(BOOL)authenticated;

@end
