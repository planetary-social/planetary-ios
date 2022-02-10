#import <Foundation/Foundation.h>
#import "PHGStorage.h"


@interface PHGFileStorage : NSObject <PHGStorage>

@property (nonatomic, strong, nullable) id<PHGCrypto> crypto;

- (instancetype _Nonnull)initWithFolder:(NSURL *_Nonnull)folderURL crypto:(id<PHGCrypto> _Nullable)crypto;

- (NSURL *_Nonnull)urlForKey:(NSString *_Nonnull)key;

+ (NSURL *_Nullable)applicationSupportDirectoryURL;
+ (NSURL *_Nullable)cachesDirectoryURL;

@end
