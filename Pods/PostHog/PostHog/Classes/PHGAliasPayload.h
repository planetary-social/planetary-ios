#import <Foundation/Foundation.h>
#import "PHGPayload.h"

NS_ASSUME_NONNULL_BEGIN


@interface PHGAliasPayload : PHGPayload

@property (nonatomic, readonly) NSString *alias;

- (instancetype)initWithAlias:(NSString *)alias;

@end

NS_ASSUME_NONNULL_END
