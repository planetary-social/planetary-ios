#import <Foundation/Foundation.h>
#import "PHGHTTPClient.h"
#import "PHGIntegration.h"
#import "PHGStorage.h"

@class PHGIdentifyPayload;
@class PHGCapturePayload;
@class PHGScreenPayload;
@class PHGAliasPayload;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PHGPostHogDidSendRequestNotification;
extern NSString *const PHGPostHogRequestDidSucceedNotification;
extern NSString *const PHGPostHogRequestDidFailNotification;


@interface PHGPostHogIntegration : NSObject <PHGIntegration>

- (id)initWithPostHog:(PHGPostHog *)posthog httpClient:(PHGHTTPClient *)httpClient fileStorage:(id<PHGStorage>)fileStorage userDefaultsStorage:(id<PHGStorage>)userDefaultsStorage;
- (NSDictionary *)staticContext;
- (NSDictionary *)liveContext;

@end

NS_ASSUME_NONNULL_END
