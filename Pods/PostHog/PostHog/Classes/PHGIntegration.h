#import <Foundation/Foundation.h>
#import "PHGIdentifyPayload.h"
#import "PHGCapturePayload.h"
#import "PHGScreenPayload.h"
#import "PHGAliasPayload.h"
#import "PHGIdentifyPayload.h"
#import "PHGContext.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PHGIntegration <NSObject>

@optional
// Identify will be called when the user calls either of the following:
// 1. [[PHGPostHog sharedInstance] identify:someDistinctId];
// 2. [[PHGPostHog sharedInstance] identify:someDistinctId properties:someProperties];
// 3. [[PHGPostHog sharedInstance] identify:someDistinctId properties:someProperties options:someOptions];
- (void)identify:(PHGIdentifyPayload *)payload;

// Capture will be called when the user calls either of the following:
// 1. [[PHGPostHog sharedInstance] capture:someEvent];
// 2. [[PHGPostHog sharedInstance] capture:someEvent properties:someProperties];
// 3. [[PHGPostHog sharedInstance] capture:someEvent properties:someProperties options:someOptions];
- (void)capture:(PHGCapturePayload *)payload;

// Screen will be called when the user calls either of the following:
// 1. [[PHGPostHog sharedInstance] screen:someEvent];
// 2. [[PHGPostHog sharedInstance] screen:someEvent properties:someProperties];
// 3. [[PHGPostHog sharedInstance] screen:someEvent properties:someProperties options:someOptions];
- (void)screen:(PHGScreenPayload *)payload;

// Alias will be called when the user calls either of the following:
// 1. [[PHGPostHog sharedInstance] alias:someNewAlias];
// 2. [[PHGPostHog sharedInstance] alias:someNewAlias options:someOptions];
- (void)alias:(PHGAliasPayload *)payload;

// Reset is invoked when the user logs out, and any data saved about the user should be cleared.
- (void)reset;

// Flush is invoked when any queued events should be uploaded.
- (void)flush;

// App Delegate Callbacks

// Callbacks for notifications changes.
// ------------------------------------
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;

// Callbacks for app state changes
// -------------------------------

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationWillTerminate;
- (void)applicationWillResignActive;
- (void)applicationDidBecomeActive;

- (void)continueUserActivity:(NSUserActivity *)activity;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options;

@end

NS_ASSUME_NONNULL_END
