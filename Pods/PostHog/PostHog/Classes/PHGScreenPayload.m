#import "PHGScreenPayload.h"


@implementation PHGScreenPayload

- (instancetype)initWithName:(NSString *)name
                  properties:(NSDictionary *)properties
{
    if (self = [super init]) {
        _name = [name copy];
        _properties = [properties copy];
    }
    return self;
}

@end
