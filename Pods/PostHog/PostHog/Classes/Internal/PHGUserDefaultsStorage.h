#import <Foundation/Foundation.h>
#import "PHGStorage.h"


@interface PHGUserDefaultsStorage : NSObject <PHGStorage>

@property (nonatomic, strong, nullable) id<PHGCrypto> crypto;
@property (nonnull, nonatomic, readonly) NSUserDefaults *defaults;
@property (nullable, nonatomic, readonly) NSString *namespacePrefix;

- (instancetype _Nonnull)initWithDefaults:(NSUserDefaults *_Nonnull)defaults namespacePrefix:(NSString *_Nullable)namespacePrefix crypto:(id<PHGCrypto> _Nullable)crypto;

@end
