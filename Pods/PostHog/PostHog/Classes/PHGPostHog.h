#import <Foundation/Foundation.h>
#import "PHGPostHogConfiguration.h"
#import "PHGSerializableValue.h"
#import "PHGCrypto.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * This object provides an API for recording posthog.
 */
@class PHGPostHogConfiguration;


@interface PHGPostHog : NSObject

/**
 * Whether or not the posthog client is currently enabled.
 */
@property (nonatomic, assign, readonly) BOOL enabled;

/**
 * Used by the posthog client to configure various options.
 */
@property (nonatomic, strong, readonly) PHGPostHogConfiguration *configuration;

/**
 * Setup this posthog client instance.
 *
 * @param configuration The configuration used to setup the client.
 */
- (instancetype)initWithConfiguration:(PHGPostHogConfiguration *)configuration;

/**
 * Setup the posthog client.
 *
 * @param configuration The configuration used to setup the client.
 */
+ (void)setupWithConfiguration:(PHGPostHogConfiguration *)configuration;

/**
 * Enabled/disables debug logging to trace your data going through the SDK.
 *
 * @param showDebugLogs `YES` to enable logging, `NO` otherwise. `NO` by default.
 */
+ (void)debug:(BOOL)showDebugLogs;

/**
 * Returns the shared posthog client.
 *
 * @see -setupWithConfiguration:
 */
+ (instancetype _Nullable)sharedPostHog;

/*!
 @method

 @abstract
 Associate a user with their unique ID and record properties about them.

 @param distinctId    A database ID (or email address) for this user. If you don't have a distinctId
 but want to record properties, you should pass nil.

 @param properties    A dictionary of properties you know about the user. Things like: email, name, plan, etc.

 @param options       A dictionary of options, such as the `@"anonymousId"` key. If no anonymous ID is specified one will be generated for you.

 @discussion
 When you learn more about who your user is, you can record that information with identify.

 */
- (void)identify:(NSString *)distinctId properties:(SERIALIZABLE_DICT _Nullable)properties options:(SERIALIZABLE_DICT _Nullable)options;
- (void)identify:(NSString *)distinctId properties:(SERIALIZABLE_DICT _Nullable)properties;
- (void)identify:(NSString *)distinctId;


/*!
 @method

 @abstract
 Record the actions your users perform.

 @param event         The name of the event you're capturing. We recommend using human-readable names
 like `Played a Song` or `Updated Status`.

 @param properties    A dictionary of properties for the event. If the event was 'Added to Shopping Cart', it might
 have properties like price, productType, etc.

 @discussion
 When a user performs an action in your app, you'll want to capture that action for later analysis. Use the event name to say what the user did, and properties to specify any interesting details of the action.

 */
- (void)capture:(NSString *)event properties:(SERIALIZABLE_DICT _Nullable)properties;
- (void)capture:(NSString *)event;

/*!
 @method

 @abstract
 Record the screens or views your users see.

 @param screenTitle   The title of the screen being viewed. We recommend using human-readable names
 like 'Photo Feed' or 'Completed Purchase Screen'.

 @param properties    A dictionary of properties for the screen view event. If the event was 'Added to Shopping Cart',
 it might have properties like price, productType, etc.

 @discussion
 When a user views a screen in your app, you'll want to record that here. For some tools like Google PostHog and Flurry, screen views are treated specially, and are different from "events" kind of like "page views" on the web. For services that don't treat "screen views" specially, we map "screen" straight to "capture" with the same parameters. For example, Mixpanel doesn't treat "screen views" any differently. So a call to "screen" will be captured as a normal event in Mixpanel, but get sent to Google PostHog and Flurry as a "screen".

 */
- (void)screen:(NSString *)screenTitle properties:(SERIALIZABLE_DICT _Nullable)properties;
- (void)screen:(NSString *)screenTitle;

/*!
 @method

 @abstract
 Merge two user identities, effectively connecting two sets of user data as one.
 This may not be supported by all integrations.

 @param alias         The new ID you want to alias the existing ID to. The existing ID will be either the
 previousId if you have called identify, or the anonymous ID.

 @discussion
 When you learn more about who the group is, you can record that information with group.

 */
- (void)alias:(NSString *)alias;

// todo: docs
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;
- (void)continueUserActivity:(NSUserActivity *)activity;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options;

/*!
 @method

 @abstract
 Trigger an upload of all queued events.

 @discussion
 This is useful when you want to force all messages queued on the device to be uploaded. Please note that not all integrations
 respond to this method.
 */
- (void)flush;

/*!
 @method

 @abstract
 Reset any user state that is cached on the device.

 @discussion
 This is useful when a user logs out and you want to clear the identity. It will clear any
 properties or distinctId's cached on the device.
 */
- (void)reset;

/*!
 @method

 @abstract
 Enable the sending of posthog data. Enabled by default.

 @discussion
 Occasionally used in conjunction with disable user opt-out handling.
 */
- (void)enable;


/*!
 @method

 @abstract
 Completely disable the sending of any posthog data.

 @discussion
 If have a way for users to actively or passively (sometimes based on location) opt-out of
 posthog data collection, you can use this method to turn off all data collection.
 */
- (void)disable;


/**
 * Version of the library.
 */
+ (NSString *)version;

/** Returns the anonymous ID of the current user. */
- (NSString *)getAnonymousId;

/** Returns the configuration used to create the posthog client. */
- (PHGPostHogConfiguration *)configuration;


@end

NS_ASSUME_NONNULL_END
