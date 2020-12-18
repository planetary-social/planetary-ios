#import "PHGIdentifyPayload.h"


@implementation PHGIdentifyPayload

- (instancetype)initWithDistinctId:(NSString *)distinctId
                       anonymousId:(NSString *)anonymousId
                        properties:(NSDictionary *)properties
{
    if (self = [super init]) {
        _distinctId = [distinctId copy];
        _anonymousId = [anonymousId copy];
        _properties = [properties copy];
    }
    return self;
}

@end
