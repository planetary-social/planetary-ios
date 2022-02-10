#include <sys/sysctl.h>

#import <UIKit/UIKit.h>
#import "PHGPostHog.h"
#import "PHGPostHogUtils.h"
#import "PHGPostHogIntegration.h"
#import "PHGReachability.h"
#import "PHGHTTPClient.h"
#import "PHGStorage.h"
#import "PHGMacros.h"
#import "PHGIdentifyPayload.h"
#import "PHGCapturePayload.h"
#import "PHGScreenPayload.h"
#import "PHGAliasPayload.h"

#if TARGET_OS_IOS
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

NSString *const PHGPostHogDidSendRequestNotification = @"PostHogDidSendRequest";
NSString *const PHGPostHogRequestDidSucceedNotification = @"PostHogRequestDidSucceed";
NSString *const PHGPostHogRequestDidFailNotification = @"PostHogRequestDidFail";

NSString *const PHGADClientClass = @"ADClient";

NSString *const PHGDistinctIdKey = @"PHGDistinctId";
NSString *const PHGQueueKey = @"PHGQueue";

NSString *const kPHGDistinctIdFilename = @"posthog.distinctId";
NSString *const kPHGQueueFilename = @"posthog.queue.plist";

static NSString *GetDeviceModel()
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char result[size];
    sysctlbyname("hw.machine", result, &size, NULL, 0);
    NSString *results = [NSString stringWithCString:result encoding:NSUTF8StringEncoding];
    return results;
}

@interface PHGPostHogIntegration ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSDictionary *_cachedStaticContext;
@property (nonatomic, strong) NSURLSessionUploadTask *batchRequest;
@property (nonatomic, assign) UIBackgroundTaskIdentifier flushTaskID;
@property (nonatomic, strong) PHGReachability *reachability;
@property (nonatomic, strong) NSTimer *flushTimer;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t backgroundTaskQueue;
@property (nonatomic, assign) PHGPostHog *posthog;
@property (nonatomic, assign) PHGPostHogConfiguration *configuration;
@property (nonatomic, copy) NSString *referrer;
@property (nonatomic, copy) NSString *distinctId;
@property (nonatomic, strong) PHGHTTPClient *httpClient;
@property (nonatomic, strong) id<PHGStorage> fileStorage;
@property (nonatomic, strong) id<PHGStorage> userDefaultsStorage;

@end


@implementation PHGPostHogIntegration

- (id)initWithPostHog:(PHGPostHog *)posthog httpClient:(PHGHTTPClient *)httpClient fileStorage:(id<PHGStorage>)fileStorage userDefaultsStorage:(id<PHGStorage>)userDefaultsStorage;
{
    if (self = [super init]) {
        self.posthog = posthog;
        self.configuration = posthog.configuration;
        self.httpClient = httpClient;
        self.httpClient.httpSessionDelegate = posthog.configuration.httpSessionDelegate;
        self.fileStorage = fileStorage;
        self.userDefaultsStorage = userDefaultsStorage;
        self.distinctId = [self getDistinctId];
        self.reachability = [PHGReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
        self.cachedStaticContext = [self staticContext];
        self.serialQueue = phg_dispatch_queue_create_specific("com.posthog", DISPATCH_QUEUE_SERIAL);
        self.backgroundTaskQueue = phg_dispatch_queue_create_specific("com.posthog.backgroundTask", DISPATCH_QUEUE_SERIAL);
        self.flushTaskID = UIBackgroundTaskInvalid;

        [self dispatchBackground:^{
            // Check for previous queue data in NSUserDefaults and remove if present.
            if ([[NSUserDefaults standardUserDefaults] objectForKey:PHGQueueKey]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:PHGQueueKey];
            }
        }];

        self.flushTimer = [NSTimer timerWithTimeInterval:self.configuration.flushInterval
                                                  target:self
                                                selector:@selector(flush)
                                                userInfo:nil
                                                 repeats:YES];
        
        [NSRunLoop.mainRunLoop addTimer:self.flushTimer
                                forMode:NSDefaultRunLoopMode];
        

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateStaticContext)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

/*
 * There is an iOS bug that causes instances of the CTTelephonyNetworkInfo class to
 * sometimes get notifications after they have been deallocated.
 * Instead of instantiating, using, and releasing instances you * must instead retain
 * and never release them to work around the bug.
 *
 * Ref: http://stackoverflow.com/questions/14238586/coretelephony-crash
 */

#if TARGET_OS_IOS
static CTTelephonyNetworkInfo *_telephonyNetworkInfo;
#endif

- (NSDictionary *)staticContext
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    NSMutableDictionary *infoDictionary = [[[NSBundle mainBundle] infoDictionary] mutableCopy];
    [infoDictionary addEntriesFromDictionary:[[NSBundle mainBundle] localizedInfoDictionary]];
    if (infoDictionary.count) {
        dict[@"$app_name"] = infoDictionary[@"CFBundleDisplayName"] ?: @"";
        dict[@"$app_version"] = infoDictionary[@"CFBundleShortVersionString"] ?: @"";
        dict[@"$app_build"] = infoDictionary[@"CFBundleVersion"] ?: @"";
        dict[@"$app_namespace"] = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    }

    UIDevice *device = [UIDevice currentDevice];

    dict[@"$device_manufacturer"] = @"Apple";
    dict[@"$device_type"] = @"ios";
    dict[@"$device_model"] = GetDeviceModel();
    dict[@"$device_id"] = self.configuration.shouldSendDeviceID ? [[device identifierForVendor] UUIDString] : nil;
    dict[@"$device_name"] = [device model];

    dict[@"$os_name"] = device.systemName;
    dict[@"$os_version"] = device.systemVersion;

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    dict[@"$screen_width"] = @(screenSize.width);
    dict[@"$screen_height"] = @(screenSize.height);

#if !(TARGET_IPHONE_SIMULATOR)
    Class adClient = NSClassFromString(PHGADClientClass);
    if (adClient) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id sharedClient = [adClient performSelector:NSSelectorFromString(@"sharedClient")];
#pragma clang diagnostic pop
        void (^completionHandler)(BOOL iad) = ^(BOOL iad) {
            if (iad) {
                dict[@"$referrer_type"] = @"iad";
            }
        };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [sharedClient performSelector:NSSelectorFromString(@"determineAppInstallationAttributionWithCompletionHandler:")
                           withObject:completionHandler];
#pragma clang diagnostic pop
    }
#endif

    return dict;
}

- (void)updateStaticContext
{
    self.cachedStaticContext = [self staticContext];
}

- (NSDictionary *)cachedStaticContext {
    __block NSDictionary *result = nil;
    weakify(self);
    dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        strongify(self);
        result = self._cachedStaticContext;
    });
    return result;
}

- (void)setCachedStaticContext:(NSDictionary *)cachedStaticContext {
    weakify(self);
    dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        strongify(self);
        self._cachedStaticContext = cachedStaticContext;
    });
}

- (NSDictionary *)liveContext
{
    NSMutableDictionary *context = [[NSMutableDictionary alloc] init];

    context[@"$lib"] = [self configuration].libraryName;
    context[@"$lib_version"] = [self configuration].libraryVersion;

    if ([NSLocale.currentLocale objectForKey:NSLocaleCountryCode]) {
        context[@"$locale"] = [NSString stringWithFormat:
                @"%@-%@",
                [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode],
                [NSLocale.currentLocale objectForKey:NSLocaleCountryCode]];
    } else {
        context[@"$locale"] = [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];
    }

    context[@"$timezone"] = [[NSTimeZone localTimeZone] name];

    if (self.reachability.isReachable) {
        context[@"$network_wifi"] = @(self.reachability.isReachableViaWiFi);
        context[@"$network_cellular"] = @(self.reachability.isReachableViaWWAN);
    } else {
        context[@"$network_wifi"] = @NO;
        context[@"$network_cellular"] = @NO;
    }

#if TARGET_OS_IOS
    static dispatch_once_t networkInfoOnceToken;
    dispatch_once(&networkInfoOnceToken, ^{
        _telephonyNetworkInfo = [[CTTelephonyNetworkInfo alloc] init];
    });

    CTCarrier *carrier = [_telephonyNetworkInfo subscriberCellularProvider];
    if (carrier.carrierName.length)
        context[@"$network_carrier"] = carrier.carrierName;
#endif

    if (self.referrer) {
        context[@"$referrer"] = [self.referrer copy];
    }

    return [context copy];
}

- (void)dispatchBackground:(void (^)(void))block
{
    phg_dispatch_specific_async(_serialQueue, block);
}

- (void)dispatchBackgroundAndWait:(void (^)(void))block
{
    phg_dispatch_specific_sync(_serialQueue, block);
}

- (void)beginBackgroundTask
{
    [self endBackgroundTask];

    phg_dispatch_specific_sync(_backgroundTaskQueue, ^{
        id<PHGApplicationProtocol> application = [self.posthog configuration].application;
        if (application) {
            self.flushTaskID = [application phg_beginBackgroundTaskWithName:@"PostHog.Flush"
                                                          expirationHandler:^{
                                                              [self endBackgroundTask];
                                                          }];
        }
    });
}

- (void)endBackgroundTask
{
    // endBackgroundTask and beginBackgroundTask can be called from main thread
    // We should not dispatch to the same queue we use to flush events because it can cause deadlock
    // inside @synchronized(self) block for PHGIntegrationsManager as both events queue and main queue
    // attempt to call forwardSelector:arguments:options:
    phg_dispatch_specific_sync(_backgroundTaskQueue, ^{
        if (self.flushTaskID != UIBackgroundTaskInvalid) {
            id<PHGApplicationProtocol> application = [self.posthog configuration].application;
            if (application) {
                [application phg_endBackgroundTask:self.flushTaskID];
            }

            self.flushTaskID = UIBackgroundTaskInvalid;
        }
    });
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, self.configuration.apiKey];
}

- (void)saveDistinctId:(NSString *)distinctId
{
    [self dispatchBackground:^{
        self.distinctId = distinctId;

#if TARGET_OS_TV
        [self.userDefaultsStorage setString:distinctId forKey:PHGDistinctIdKey];
#else
        [self.fileStorage setString:distinctId forKey:kPHGDistinctIdFilename];
#endif
    }];
}

#pragma mark - PostHog API

- (void)identify:(PHGIdentifyPayload *)payload
{
    [self dispatchBackground:^{
        [self saveDistinctId:payload.distinctId];
    }];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    [dictionary setValue:@"$identify" forKey:@"event"];
    [dictionary setValue:payload.distinctId ?: payload.anonymousId ?: [self.posthog getAnonymousId] forKey:@"distinct_id"];
    [dictionary setValue:payload.properties forKey:@"$set"];

    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    if (payload.distinctId) {
        [properties setValue:payload.anonymousId ?: [self.posthog getAnonymousId] forKey:@"$anon_distinct_id"];
    }
    [dictionary setValue:properties forKey:@"properties"];

    [self enqueueAction:dictionary];
}

- (void)capture:(PHGCapturePayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:self.distinctId ?: [self.posthog getAnonymousId] forKey:@"distinct_id"];
    [dictionary setValue:payload.event forKey:@"event"];

    NSMutableDictionary *properties = [[NSMutableDictionary alloc] initWithDictionary:payload.properties copyItems:YES];
    [dictionary setValue:properties forKey:@"properties"];

    [self enqueueAction:dictionary];
}

- (void)screen:(PHGScreenPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:self.distinctId ?: [self.posthog getAnonymousId] forKey:@"distinct_id"];
    [dictionary setValue:@"$screen" forKey:@"event"];

    NSMutableDictionary *properties = [[NSMutableDictionary alloc] initWithDictionary:payload.properties copyItems:YES];
    [properties setValue:payload.name forKey:@"$screen_name"];
    [dictionary setValue:properties forKey:@"properties"];

    [self enqueueAction:dictionary];
}

- (void)alias:(PHGAliasPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:@"$create_alias" forKey:@"event"];

    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    [properties setValue:self.distinctId ?: [self.posthog getAnonymousId] forKey:@"distinct_id"];
    [properties setValue:payload.alias forKey:@"alias"];
    [dictionary setValue:properties forKey:@"properties"];

    [self enqueueAction:dictionary];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSCParameterAssert(deviceToken != nil);

    const unsigned char *buffer = (const unsigned char *)[deviceToken bytes];
    if (!buffer) {
        return;
    }
    NSMutableString *token = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [token appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];
    }
    [self.cachedStaticContext[@"device"] setObject:[token copy] forKey:@"token"];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        self.referrer = activity.webpageURL.absoluteString;
    }
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    self.referrer = url.absoluteString;
}

#pragma mark - Queueing

- (void)enqueueAction:(NSMutableDictionary *)payload
{
    // attach these parts of the payload outside since they are all synchronous
    // and the timestamp will be more accurate.
    payload[@"timestamp"] = createISO8601FormattedString([NSDate date]);
    payload[@"message_id"] = createUUIDString();

    [self dispatchBackground:^{
        // attach distinctId and anonymousId inside the dispatch_async in case
        // they've changed (see identify function)

        NSDictionary *staticContext = self.cachedStaticContext;
        NSDictionary *liveContext = [self liveContext];

        NSMutableDictionary *properties = payload[@"properties"];
        [properties addEntriesFromDictionary:staticContext];
        [properties addEntriesFromDictionary:liveContext];
        [payload setValue:[properties copy] forKey:@"properties"];

        PHGLog(@"%@ Enqueueing action: %@", self, payload);
        [self queuePayload:[payload copy]];
    }];
}

- (void)queuePayload:(NSDictionary *)payload
{
    @try {
        // Trim the queue to maxQueueSize - 1 before we add a new element.
        trimQueueItems(self.queue, self.posthog.configuration.maxQueueSize - 1);
        [self.queue addObject:payload];
        [self persistQueue];
        [self flushQueueByLength];
    }
    @catch (NSException *exception) {
        PHGLog(@"%@ Error writing payload: %@", self, exception);
    }
}

- (void)flush
{
    [self flushWithMaxSize:self.maxBatchSize];
}

- (void)flushWithMaxSize:(NSUInteger)maxBatchSize
{
    [self dispatchBackground:^{
        if ([self.queue count] == 0) {
            PHGLog(@"%@ No queued API calls to flush.", self);
            [self endBackgroundTask];
            return;
        }
        if (self.batchRequest != nil) {
            PHGLog(@"%@ API request already in progress, not flushing again.", self);
            return;
        }

        NSArray *batch;
        if ([self.queue count] >= maxBatchSize) {
            batch = [self.queue subarrayWithRange:NSMakeRange(0, maxBatchSize)];
        } else {
            batch = [NSArray arrayWithArray:self.queue];
        }

        [self sendData:batch];
    }];
}

- (void)flushQueueByLength
{
    [self dispatchBackground:^{
        PHGLog(@"%@ Length is %lu.", self, (unsigned long)self.queue.count);

        if (self.batchRequest == nil && [self.queue count] >= self.configuration.flushAt) {
            [self flush];
        }
    }];
}

- (void)reset
{
    [self dispatchBackgroundAndWait:^{
#if TARGET_OS_TV
        [self.userDefaultsStorage removeKey:PHGDistinctIdKey];
#else
        [self.fileStorage removeKey:kPHGDistinctIdFilename];
#endif
        self.distinctId = nil;
    }];
}

- (void)notifyForName:(NSString *)name userInfo:(id)userInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:userInfo];
        PHGLog(@"sent notification %@", name);
    });
}

- (void)sendData:(NSArray *)batch
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
    [payload setObject:createISO8601FormattedString([NSDate date]) forKey:@"sent_at"];
    [payload setObject:batch forKey:@"batch"];
    [payload setObject:self.configuration.apiKey forKey:@"api_key"];

    PHGLog(@"%@ Flushing %lu of %lu queued API calls.", self, (unsigned long)batch.count, (unsigned long)self.queue.count);
    PHGLog(@"Flushing batch %@.", payload);

    self.batchRequest = [self.httpClient upload:payload host:self.configuration.host completionHandler:^(BOOL retry) {
        [self dispatchBackground:^{
            if (retry) {
                [self notifyForName:PHGPostHogRequestDidFailNotification userInfo:batch];
                self.batchRequest = nil;
                [self endBackgroundTask];
                return;
            }

            [self.queue removeObjectsInArray:batch];
            [self persistQueue];
            [self notifyForName:PHGPostHogRequestDidSucceedNotification userInfo:batch];
            self.batchRequest = nil;
            [self endBackgroundTask];
        }];
    }];

    [self notifyForName:PHGPostHogDidSendRequestNotification userInfo:batch];
}

- (void)applicationDidEnterBackground
{
    [self beginBackgroundTask];
    // We are gonna try to flush as much as we reasonably can when we enter background
    // since there is a chance that the user will never launch the app again.
    [self flush];
}

- (void)applicationWillTerminate
{
    [self dispatchBackgroundAndWait:^{
        if (self.queue.count)
            [self persistQueue];
    }];
}

#pragma mark - Private

- (NSMutableArray *)queue
{
    if (!_queue) {
        _queue = [[self.fileStorage arrayForKey:kPHGQueueFilename] ?: @[] mutableCopy];
    }

    return _queue;
}

- (NSUInteger)maxBatchSize
{
    return 100;
}

- (NSString *)getDistinctId
{
#if TARGET_OS_TV
    return [[NSUserDefaults standardUserDefaults] valueForKey:PHGDistinctIdKey];
#else
    return [self.fileStorage stringForKey:kPHGDistinctIdFilename];
#endif
}

- (void)persistQueue
{
    [self.fileStorage setArray:[self.queue copy] forKey:kPHGQueueFilename];
}

@end
