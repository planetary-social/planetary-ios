#import "PHGCapturePayload.h"


@implementation PHGCapturePayload


- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *)properties
{
    if (self = [super init]) {
        _event = [event copy];
        _properties = [properties copy];
    }
    return self;
}

@end
