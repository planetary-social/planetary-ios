#import "PHGContext.h"
#import "PHGPayload.h"


@interface PHGContext () <PHGMutableContext>

@property (nonatomic) PHGEventType eventType;
@property (nonatomic, nullable) NSString *distinctId;
@property (nonatomic, nullable) NSString *anonymousId;
@property (nonatomic, nullable) PHGPayload *payload;
@property (nonatomic, nullable) NSError *error;
@property (nonatomic) BOOL debug;

@end


@implementation PHGContext

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Bad Initization"
                                   reason:@"Please use initWithPostHog:"
                                 userInfo:nil];
}

- (instancetype)initWithPostHog:(PHGPostHog *)posthog
{
    if (self = [super init]) {
        __posthog = posthog;
// TODO: Have some other way of indicating the debug flag is on too.
// Also, for logging it'd be damn nice to implement a logging protocol
// such as CocoalumberJack and allow developers to pipe logs to wherever they want
// Of course we wouldn't us depend on it. it'd be like a soft dependency where
// posthog-ios would totally work without it but works even better with it!
#ifdef DEBUG
        _debug = YES;
#endif
    }
    return self;
}

- (PHGContext *_Nonnull)modify:(void (^_Nonnull)(id<PHGMutableContext> _Nonnull ctx))modify
{
    // We're also being a bit clever here by implementing PHGContext actually as a mutable
    // object but hiding that implementation detail from consumer of the API.
    // In production also instead of copying self we simply just return self
    // because the net effect is the same anyways. In the end we get a lot of the benefits
    // of immutable data structure without the cost of having to allocate and reallocate
    // objects over and over again.
    PHGContext *context = self.debug ? [self copy] : self;
    modify(context);
    // TODO: We could probably add some validation here that the newly modified context
    // is actualy valid. For example, `eventType` should match `paylaod` class.
    // or anonymousId should never be null.
    return context;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    PHGContext *ctx = [[PHGContext allocWithZone:zone] initWithPostHog:self._posthog];
    ctx.eventType = self.eventType;
    ctx.distinctId = self.distinctId;
    ctx.anonymousId = self.anonymousId;
    ctx.payload = self.payload;
    ctx.error = self.error;
    ctx.debug = self.debug;
    return ctx;
}

@end
