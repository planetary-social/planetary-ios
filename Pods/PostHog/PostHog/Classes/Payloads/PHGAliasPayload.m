#import "PHGAliasPayload.h"


@implementation PHGAliasPayload

- (instancetype)initWithAlias:(NSString *)alias
{
    if (self = [super init]) {
        _alias = [alias copy];
    }
    return self;
}

@end
