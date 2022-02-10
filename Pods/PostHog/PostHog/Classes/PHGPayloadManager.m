#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "PHGPostHogUtils.h"
#import "PHGPostHog.h"
#import "PHGHTTPClient.h"
#import "PHGStorage.h"
#import "PHGFileStorage.h"
#import "PHGUserDefaultsStorage.h"
#import "PHGPayloadManager.h"
#import "PHGPostHogIntegration.h"

NSString *PHGPostHogIntegrationDidStart = @"com.posthog.integration.did.start";
static NSString *const PHGAnonymousIdKey = @"PHGAnonymousId";
static NSString *const kPHGAnonymousIdFilename = @"posthog.anonymousId";


@interface PHGPayloadManager ()

@property (nonatomic, strong) PHGPostHog *posthog;
@property (nonatomic, strong) PHGPostHogConfiguration *configuration;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, strong) PHGPostHogIntegration *integration;
@property (nonatomic) volatile BOOL initialized;
@property (nonatomic, copy) NSString *cachedAnonymousId;
@property (nonatomic, strong) PHGHTTPClient *httpClient;
@property (nonatomic, strong) id<PHGStorage> userDefaultsStorage;
@property (nonatomic, strong) id<PHGStorage> fileStorage;

@end


@implementation PHGPayloadManager

- (instancetype _Nonnull)initWithPostHog:(PHGPostHog *_Nonnull)posthog
{
    PHGPostHogConfiguration *configuration = posthog.configuration;
    NSCParameterAssert(configuration != nil);

    if (self = [super init]) {
        self.posthog = posthog;
        self.configuration = configuration;
        self.serialQueue = phg_dispatch_queue_create_specific("com.posthog", DISPATCH_QUEUE_SERIAL);
        self.messageQueue = [[NSMutableArray alloc] init];
        self.httpClient = [[PHGHTTPClient alloc] initWithRequestFactory:configuration.requestFactory];
        
        self.userDefaultsStorage = [[PHGUserDefaultsStorage alloc] initWithDefaults:[NSUserDefaults standardUserDefaults] namespacePrefix:nil crypto:configuration.crypto];
        #if TARGET_OS_TV
            self.fileStorage = [[PHGFileStorage alloc] initWithFolder:[PHGFileStorage cachesDirectoryURL] crypto:configuration.crypto];
        #else
            self.fileStorage = [[PHGFileStorage alloc] initWithFolder:[PHGFileStorage applicationSupportDirectoryURL] crypto:configuration.crypto];
        #endif

        self.cachedAnonymousId = [self loadOrGenerateAnonymousID:NO];

        self.integration = [[PHGPostHogIntegration alloc] initWithPostHog:self.posthog httpClient:self.self.httpClient fileStorage:self.fileStorage userDefaultsStorage:self.userDefaultsStorage];

        [[NSNotificationCenter defaultCenter] postNotificationName:PHGPostHogIntegrationDidStart object:@"PostHog" userInfo:nil];
        [self flushMessageQueue];

        self.initialized = true;
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleAppStateNotification:(NSString *)notificationName
{
    PHGLog(@"Application state change notification: %@", notificationName);
    static NSDictionary *selectorMapping;
    static dispatch_once_t selectorMappingOnce;
    dispatch_once(&selectorMappingOnce, ^{
        selectorMapping = @{
            UIApplicationDidEnterBackgroundNotification :
                NSStringFromSelector(@selector(applicationDidEnterBackground)),
            UIApplicationWillTerminateNotification :
                NSStringFromSelector(@selector(applicationWillTerminate)),
        };
    });
    SEL selector = NSSelectorFromString(selectorMapping[notificationName]);
    if (selector) {
        [self callWithSelector:selector arguments:nil options:nil];
    }
}


#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

#pragma mark - PostHog API

- (void)identify:(NSString *)distinctId properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(distinctId.length > 0, @"distinctId (%@) must not be empty.", distinctId);

    NSString *anonymousId = [options objectForKey:@"$anon_distinct_id"];
    if (anonymousId) {
        [self saveAnonymousId:anonymousId];
    } else {
        anonymousId = self.cachedAnonymousId;
    }

    PHGIdentifyPayload *payload = [[PHGIdentifyPayload alloc] initWithDistinctId:distinctId
                                                                     anonymousId:anonymousId
                                                                      properties:PHGCoerceDictionary(properties)];

    [self callWithSelector:NSSelectorFromString(@"identify:")
                             arguments:@[ payload ]
                               options:options];
}

#pragma mark - Capture

- (void)capture:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(event.length > 0, @"event (%@) must not be empty.", event);

    PHGCapturePayload *payload = [[PHGCapturePayload alloc] initWithEvent:event
                                                               properties:PHGCoerceDictionary(properties)];

    [self callWithSelector:NSSelectorFromString(@"capture:")
                             arguments:@[ payload ]
                               options:options];
}

#pragma mark - Screen

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(screenTitle.length > 0, @"screen name (%@) must not be empty.", screenTitle);

    PHGScreenPayload *payload = [[PHGScreenPayload alloc] initWithName:screenTitle
                                                            properties:PHGCoerceDictionary(properties)];

    [self callWithSelector:NSSelectorFromString(@"screen:")
                             arguments:@[ payload ]
                               options:options];
}

#pragma mark - Alias

- (void)alias:(NSString *)alias options:(NSDictionary *)options
{
    PHGAliasPayload *payload = [[PHGAliasPayload alloc] initWithAlias:alias];

    [self callWithSelector:NSSelectorFromString(@"alias:")
                             arguments:@[ payload ]
                               options:options];
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    [self callWithSelector:_cmd arguments:@[ userInfo ] options:nil];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    [self callWithSelector:_cmd arguments:@[ error ] options:nil];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);

    [self callWithSelector:_cmd arguments:@[ deviceToken ] options:nil];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    [self callWithSelector:_cmd arguments:@[ identifier, userInfo ] options:nil];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    [self callWithSelector:_cmd arguments:@[ activity ] options:nil];
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    [self callWithSelector:_cmd arguments:@[ url, options ] options:nil];
}

- (void)reset
{
    [self resetAnonymousId];
    [self callWithSelector:_cmd arguments:nil options:nil];
}

- (void)resetAnonymousId
{
    self.cachedAnonymousId = [self loadOrGenerateAnonymousID:YES];
}

- (NSString *)getAnonymousId;
{
    return self.cachedAnonymousId;
}

- (NSString *)loadOrGenerateAnonymousID:(BOOL)reset
{
#if TARGET_OS_TV
    NSString *anonymousId = [self.userDefaultsStorage stringForKey:PHGAnonymousIdKey];
#else
    NSString *anonymousId = [self.fileStorage stringForKey:kPHGAnonymousIdFilename];
#endif

    if (!anonymousId || reset) {
        // We've chosen to generate a UUID rather than use the UDID (deprecated in iOS 5),
        // identifierForVendor (iOS6 and later, can't be changed on logout),
        // or MAC address (blocked in iOS 7).
        anonymousId = createUUIDString();
        PHGLog(@"New anonymousId: %@", anonymousId);
#if TARGET_OS_TV
        [self.userDefaultsStorage setString:anonymousId forKey:PHGAnonymousIdKey];
#else
        [self.fileStorage setString:anonymousId forKey:kPHGAnonymousIdFilename];
#endif
    }
    return anonymousId;
}

- (void)saveAnonymousId:(NSString *)anonymousId
{
    self.cachedAnonymousId = anonymousId;
#if TARGET_OS_TV
    [self.userDefaultsStorage setString:anonymousId forKey:PHGAnonymousIdKey];
#else
    [self.fileStorage setString:anonymousId forKey:kPHGAnonymousIdFilename];
#endif
}

- (void)flush
{
    [self callWithSelector:_cmd arguments:nil options:nil];
}

#pragma mark - Private

- (void)forwardSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    [self invokeIntegration:self.integration key:@"PostHog" selector:selector arguments:arguments options:options];
}

- (void)invokeIntegration:(PHGPostHogIntegration *)integration key:(NSString *)key selector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    NSString *eventType = NSStringFromSelector(selector);
    PHGLog(@"Running: %@ with arguments %@ on integration: %@", eventType, arguments, key);
    NSInvocation *invocation = [self invocationForSelector:selector arguments:arguments];
    [invocation invokeWithTarget:integration];
}

- (NSInvocation *)invocationForSelector:(SEL)selector arguments:(NSArray *)arguments
{
    NSMethodSignature *signature = [PHGPostHogIntegration instanceMethodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    for (int i = 0; i < arguments.count; i++) {
        id argument = (arguments[i] == [NSNull null]) ? nil : arguments[i];
        [invocation setArgument:&argument atIndex:i + 2];
    }
    return invocation;
}

- (void)queueSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    NSArray *obj = @[ NSStringFromSelector(selector), arguments ?: @[], options ?: @{} ];
    PHGLog(@"Queueing: %@", obj);
    [_messageQueue addObject:obj];
}

- (void)flushMessageQueue
{
    if (_messageQueue.count != 0) {
        for (NSArray *arr in _messageQueue)
            [self forwardSelector:NSSelectorFromString(arr[0]) arguments:arr[1] options:arr[2]];
        [_messageQueue removeAllObjects];
    }
}

- (void)callWithSelector:(SEL)selector arguments:(NSArray *)arguments options:(NSDictionary *)options
{
    phg_dispatch_specific_async(_serialQueue, ^{
        if (self.initialized) {
            [self flushMessageQueue];
            [self forwardSelector:selector arguments:arguments options:options];
        } else {
            [self queueSelector:selector arguments:arguments options:options];
        }
    });
}

@end


@interface PHGPayload (Options)
@property (readonly) NSDictionary *options;
@end


@implementation PHGPayload (Options)

// Combine context into options
- (NSDictionary *)options
{
    return @{};
}

@end


@implementation PHGPayloadManager (PHGMiddleware)

- (void)context:(PHGContext *)context next:(void (^_Nonnull)(PHGContext *_Nullable))next
{
    switch (context.eventType) {
        case PHGEventTypeIdentify: {
            PHGIdentifyPayload *p = (PHGIdentifyPayload *)context.payload;
            NSDictionary *options;
            if (p.anonymousId) {
                NSMutableDictionary *mutableOptions = [[NSMutableDictionary alloc] initWithDictionary:p.options];
                mutableOptions[@"$anon_distinct_id"] = p.anonymousId;
                options = [mutableOptions copy];
            } else {
                options =  p.options;
            }
            [self identify:p.distinctId properties:p.properties options:options];
            break;
        }
        case PHGEventTypeCapture: {
            PHGCapturePayload *p = (PHGCapturePayload *)context.payload;
            [self capture:p.event properties:p.properties options:p.options];
            break;
        }
        case PHGEventTypeScreen: {
            PHGScreenPayload *p = (PHGScreenPayload *)context.payload;
            [self screen:p.name properties:p.properties options:p.options];
            break;
        }
        case PHGEventTypeAlias: {
            PHGAliasPayload *p = (PHGAliasPayload *)context.payload;
            [self alias:p.alias options:p.options];
            break;
        }
        case PHGEventTypeReset:
            [self reset];
            break;
        case PHGEventTypeFlush:
            [self flush];
            break;
        case PHGEventTypeReceivedRemoteNotification:
            [self receivedRemoteNotification:
                      [(PHGRemoteNotificationPayload *)context.payload userInfo]];
            break;
        case PHGEventTypeFailedToRegisterForRemoteNotifications:
            [self failedToRegisterForRemoteNotificationsWithError:
                      [(PHGRemoteNotificationPayload *)context.payload error]];
            break;
        case PHGEventTypeRegisteredForRemoteNotifications:
            [self registeredForRemoteNotificationsWithDeviceToken:
                      [(PHGRemoteNotificationPayload *)context.payload deviceToken]];
            break;
        case PHGEventTypeHandleActionWithForRemoteNotification: {
            PHGRemoteNotificationPayload *payload = (PHGRemoteNotificationPayload *)context.payload;
            [self handleActionWithIdentifier:payload.actionIdentifier
                       forRemoteNotification:payload.userInfo];
            break;
        }
        case PHGEventTypeApplicationLifecycle:
            [self handleAppStateNotification:
                      [(PHGApplicationLifecyclePayload *)context.payload notificationName]];
            break;
        case PHGEventTypeContinueUserActivity:
            [self continueUserActivity:
                      [(PHGContinueUserActivityPayload *)context.payload activity]];
            break;
        case PHGEventTypeOpenURL: {
            PHGOpenURLPayload *payload = (PHGOpenURLPayload *)context.payload;
            [self openURL:payload.url options:payload.options];
            break;
        }
        case PHGEventTypeUndefined:
            NSAssert(NO, @"Received context with undefined event type %@", context);
            NSLog(@"[ERROR]: Received context with undefined event type %@", context);
            break;
    }
    next(context);
}

@end
