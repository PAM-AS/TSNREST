//
//  NSData+TSNRESTAuthenticatedDownload.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 25.02.15.
//
//

#import <Foundation/Foundation.h>

@interface NSData (TSNRESTAuthenticatedDownload)

/**
 Synchronous, authenticated data download.
 
 @params url The URL where the data is located
 @params authenticated Wether to authenticate using default headers
 @returns The data found at the URL
 */
+ (NSData *)dataWithContentsOfURL:(NSURL *)url authenticated:(BOOL)authenticated;

@end
