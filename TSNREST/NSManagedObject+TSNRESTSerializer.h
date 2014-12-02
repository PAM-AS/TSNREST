//
//  NSManagedObject+TSNRESTSerializer.h
//  Pods
//
//  Created by Thomas Sunde Nielsen on 02.12.14.
//
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (TSNRESTSerializer)

- (NSDictionary *)dictionaryRepresentation;
- (NSDictionary *)dictionaryRepresentationWithOptionalKeys:(NSArray *)optionalKeys;
- (NSDictionary *)dictionaryRepresentationWithOptionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys;
- (NSDictionary *)dictionaryRepresentation;

- (NSData *)jsonDataRepresentation;
- (NSData *)jsonDataRepresentationWithOptionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys;
- (NSString *)jsonStringRepresentation;
- (NSString *)jsonStringRepresentationWithOptionalKeys:(NSArray *)optionalKeys excludingKeys:(NSArray *)excludingKeys;

@end
