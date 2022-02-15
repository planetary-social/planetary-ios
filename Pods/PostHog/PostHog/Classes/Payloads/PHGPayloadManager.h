#import <Foundation/Foundation.h>
#import "PHGMiddleware.h"

/**
 * NSNotification name, that is posted after integrations are loaded.
 */
extern NSString *_Nonnull PHGPostHogIntegrationDidStart;

@class PHGPostHog;


@interface PHGPayloadManager : NSObject

- (instancetype _Nonnull)initWithPostHog:(PHGPostHog *_Nonnull)posthog;

// @Deprecated - Exposing for backward API compat reasons only
- (NSString *_Nonnull)getAnonymousId;

@end


@interface PHGPayloadManager (PHGMiddleware) <PHGMiddleware>

@end
