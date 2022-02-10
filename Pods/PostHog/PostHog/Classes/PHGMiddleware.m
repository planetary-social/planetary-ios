#import "PHGUtils.h"
#import "PHGMiddleware.h"


@implementation PHGBlockMiddleware

- (instancetype)initWithBlock:(PHGMiddlewareBlock)block
{
    if (self = [super init]) {
        _block = block;
    }
    return self;
}

- (void)context:(PHGContext *)context next:(PHGMiddlewareNext)next
{
    self.block(context, next);
}

@end


@implementation PHGMiddlewareRunner

- (instancetype)initWithMiddlewares:(NSArray<id<PHGMiddleware>> *_Nonnull)middlewares
{
    if (self = [super init]) {
        _middlewares = middlewares;
    }
    return self;
}

- (void)run:(PHGContext *_Nonnull)context callback:(RunMiddlewaresCallback _Nullable)callback
{
    [self runMiddlewares:self.middlewares context:context callback:callback];
}

// TODO: Maybe rename PHGContext to PHGEvent to be a bit more clear?
// We could also use some sanity check / other types of logging here.
- (void)runMiddlewares:(NSArray<id<PHGMiddleware>> *_Nonnull)middlewares
               context:(PHGContext *_Nonnull)context
              callback:(RunMiddlewaresCallback _Nullable)callback
{
    BOOL earlyExit = context == nil;
    if (middlewares.count == 0 || earlyExit) {
        if (callback) {
            callback(earlyExit, middlewares);
        }
        return;
    }

    [middlewares[0] context:context next:^(PHGContext *_Nullable newContext) {
        NSArray *remainingMiddlewares = [middlewares subarrayWithRange:NSMakeRange(1, middlewares.count - 1)];
        [self runMiddlewares:remainingMiddlewares context:newContext callback:callback];
    }];
}

@end
