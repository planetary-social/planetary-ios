#import <Foundation/Foundation.h>
#import "PHGPostHogUtils.h"


@interface PHGUtils : NSObject

+ (NSData *_Nullable)dataFromPlist:(nonnull id)plist;
+ (id _Nullable)plistFromData:(NSData *_Nonnull)data;

+ (id _Nullable)traverseJSON:(id _Nullable)object andReplaceWithFilters:(nonnull NSDictionary<NSString*, NSString*>*)patterns;

@end
