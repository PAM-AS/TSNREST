//
//  NSObject+PropertyClass.m
//  shopapp
//
//  Created by Thomas Sunde Nielsen on 03.02.14.
//  Copyright (c) 2014 PAM. All rights reserved.
//

#import "NSObject+PropertyClass.h"
#import <objc/runtime.h>

@implementation NSObject (PropertyClass)

-(Class)classOfPropertyNamed:(NSString*) propertyName
{ return NSClassFromString([self typeOfPropertyNamed:propertyName]); }

-(NSString*)typeOfPropertyNamed:(NSString*) propertyName
{
    // Get Class of property to be populated.
    NSString *propertyType = nil;
    
    objc_property_t property = class_getProperty([self class], [propertyName UTF8String]);
    if (property == NULL) return nil;
    
    const char *propertyAttributesCString = property_getAttributes(property);
    if (propertyAttributesCString == NULL) return nil;
    
    NSString *propertyAttributes = [NSString stringWithCString:propertyAttributesCString encoding:NSUTF8StringEncoding];
    NSArray *splitPropertyAttributes = [propertyAttributes componentsSeparatedByString:@","];
    if (splitPropertyAttributes.count > 0)
    {
        // Objective-C Runtime Programming Guide
        // xcdoc://ios//library/prerelease/ios/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
        NSString *encodeType = splitPropertyAttributes[0];
        NSArray *splitEncodeType = [encodeType componentsSeparatedByString:@"\""];
        propertyType = (splitEncodeType.count > 1) ? splitEncodeType[1] : [self typeNameForTypeEncoding:encodeType];
    }
    return propertyType;
    
}

-(NSString*)typeNameForTypeEncoding:(NSString*) typeEncoding
{
    // Type Encodings
    // xcdoc://ios//library/prerelease/ios/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
    NSDictionary *typeNamesForTypeEncodings = @{
                                                @"Tc" : @"char",
                                                @"Ti" : @"int",
                                                @"Ts" : @"short",
                                                @"Tl" : @"long",
                                                @"Tq" : @"long long",
                                                @"TC" : @"unsigned char",
                                                @"TI" : @"unsigned int",
                                                @"TS" : @"unsigned short",
                                                @"TL" : @"unsigned long",
                                                @"TQ" : @"unsigned long long",
                                                @"Tf" : @"float",
                                                @"Td" : @"double",
                                                @"Tv" : @"void",
                                                @"T*" : @"character string",
                                                @"T@" : @"id",
                                                @"T#" : @"Class",
                                                @"T:" : @"SEL",
                                                };
    
    if ([[typeNamesForTypeEncodings allKeys] containsObject:typeEncoding])
    { return [typeNamesForTypeEncodings objectForKey:typeEncoding]; }
    return @"unknown";
}

@end
