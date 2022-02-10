#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol PHGApplicationProtocol <NSObject>
@property (nullable, nonatomic, assign) id<UIApplicationDelegate> delegate;
- (NSUInteger)phg_beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void (^__nullable)(void))handler;
- (void)phg_endBackgroundTask:(NSUInteger)identifier;
@end


@interface UIApplication (PHGApplicationProtocol) <PHGApplicationProtocol>
@end

typedef NSMutableURLRequest *_Nonnull (^PHGRequestFactory)(NSURL *_Nonnull);

@protocol PHGCrypto;
@protocol PHGMiddleware;

/**
 * This object provides a set of properties to control various policies of the posthog client. Other than `apiKey`, these properties can be changed at any time.
 */
@interface PHGPostHogConfiguration : NSObject

/**
 * Creates and returns a configuration with default settings and the given API key.
 *
 * @param apiKey Your team's API key.
 */
+ (_Nonnull instancetype)configurationWithApiKey:(NSString *_Nonnull)apiKey;

/**
 * Creates and returns a configuration with default settings and the given API key.
 *
 * @param apiKey Your team's API key.
 * @param host Your API host
 */
+ (_Nonnull instancetype)configurationWithApiKey:(NSString *_Nonnull)apiKey host:(NSString *_Nonnull)host;

/**
 * Your team's API key.
 *
 * @see +configurationWithApiKey:
 */
@property (nonatomic, copy, readonly, nonnull) NSString *apiKey;

/**
 * Your API host.
 *
 * @see +configurationWithApiKey:
 */
@property (nonatomic, copy, readonly, nonnull) NSURL *host;

/**
 * Override the $lib property, used by the React Native client
 */
@property (nonatomic, copy, nonnull) NSString *libraryName;

/**
 * Override the $lib_version property, used by the React Native client
 */
@property (nonatomic, copy, nonnull) NSString *libraryVersion;

/**
 * Whether the posthog client should use location services.
 * If `YES` and the host app hasn't asked for permission to use location services then the user will be presented with an alert view asking to do so. `NO` by default.
 * If `YES`, please make sure to add a description for `NSLocationAlwaysUsageDescription` in your `Info.plist` explaining why your app is accessing Location APIs.
 */
@property (nonatomic, assign) BOOL shouldUseLocationServices;

/**
 * The number of queued events that the posthog client should flush at. Setting this to `1` will not queue any events and will use more battery. `20` by default.
 */
@property (nonatomic, assign) NSUInteger flushAt;

/**
 * The amount of time to wait before each tick of the flush timer.
 * Smaller values will make events delivered in a more real-time manner and also use more battery.
 * A value smaller than 10 seconds will seriously degrade overall performance.
 * 30 seconds by default.
 */
@property (nonatomic, assign) NSTimeInterval flushInterval;

/**
 * The maximum number of items to queue before starting to drop old ones. This should be a value greater than zero, the behaviour is undefined otherwise. `1000` by default.
 */
@property (nonatomic, assign) NSUInteger maxQueueSize;

/**
 * Whether the posthog client should automatically make a capture call for application lifecycle events, such as "Application Installed", "Application Updated" and "Application Opened".
 */
@property (nonatomic, assign) BOOL captureApplicationLifecycleEvents;


/**
 * Whether the posthog client should record bluetooth information. If `YES`, please make sure to add a description for `NSBluetoothPeripheralUsageDescription` in your `Info.plist` explaining explaining why your app is accessing Bluetooth APIs. `NO` by default.
 */
@property (nonatomic, assign) BOOL shouldUseBluetooth;

/**
 * Whether the posthog client should automatically make a screen call when a view controller is added to a view hierarchy. Because the underlying implementation uses method swizzling, we recommend initializing the posthog client as early as possible (before any screens are displayed), ideally during the Application delegate's applicationDidFinishLaunching method.
 */
@property (nonatomic, assign) BOOL recordScreenViews;

/**
 * Whether the posthog client should automatically capture in-app purchases from the App Store.
 */
@property (nonatomic, assign) BOOL captureInAppPurchases;

/**
 * Whether the posthog client should automatically capture push notifications.
 */
@property (nonatomic, assign) BOOL capturePushNotifications;

/**
 * Whether the posthog client should automatically capture deep links. You'll still need to call the continueUserActivity and openURL methods on the posthog client.
 */
@property (nonatomic, assign) BOOL captureDeepLinks;

/**
 * Whether the posthog client should include the `$device_id` property when sending events. When enabled, `UIDevice`'s `identifierForVendor` property is used.
 * Changing the value of this property after initializing the client will have no effect.
 * The default value is `YES`.
 */
@property (nonatomic, assign) BOOL shouldSendDeviceID;

/**
 * Dictionary indicating the options the app was launched with.
 */
@property (nonatomic, strong, nullable) NSDictionary *launchOptions;

/**
 * Set a custom request factory.
 */
@property (nonatomic, strong, nullable) PHGRequestFactory requestFactory;

/**
 * Set a custom crypto
 */
@property (nonatomic, strong, nullable) id<PHGCrypto> crypto;

/**
 * Set custom middlewares. Will be run before all integrations
 */
@property (nonatomic, strong, nullable) NSArray<id<PHGMiddleware>> *middlewares;

/**
 * Leave this nil for iOS extensions, otherwise set to UIApplication.sharedApplication.
 */
@property (nonatomic, strong, nullable) id<PHGApplicationProtocol> application;

/**
 * A dictionary of filters to redact payloads before they are sent.
 * This is an experimental feature that currently only applies to Deep Links.
 * It is subject to change to allow for more flexible customizations in the future.
 *
 * The key of this dictionary should be a regular expression string pattern,
 * and the value should be a regular expression substitution template.
 *
 * By default, this contains a Facebook auth token filter, configured as such:
 * @code
 * @"(fb\\d+://authorize#access_token=)([^ ]+)": @"$1((redacted/fb-auth-token))"
 * @endcode
 *
 * This will replace any matching occurences to a redacted version:
 * @code
 * "fb123456789://authorize#access_token=secretsecretsecretsecret&some=data"
 * @endcode
 *
 * Becomes:
 * @code
 * "fb123456789://authorize#access_token=((redacted/fb-auth-token))"
 * @endcode
 *
 */
@property (nonatomic, strong, nonnull) NSDictionary<NSString*, NSString*>* payloadFilters;

/**
 * An optional delegate that handles NSURLSessionDelegate callbacks
 */
@property (nonatomic, strong, nullable) id<NSURLSessionDelegate> httpSessionDelegate;

@end
