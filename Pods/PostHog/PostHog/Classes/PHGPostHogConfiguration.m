#import "PHGPostHogConfiguration.h"
#import "PHGPostHog.h"


@implementation UIApplication (PHGApplicationProtocol)

- (UIBackgroundTaskIdentifier)phg_beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void (^__nullable)(void))handler
{
    return [self beginBackgroundTaskWithName:taskName expirationHandler:handler];
}

- (void)phg_endBackgroundTask:(UIBackgroundTaskIdentifier)identifier
{
    [self endBackgroundTask:identifier];
}

@end


@interface PHGPostHogConfiguration ()

@property (nonatomic, copy, readwrite) NSString *apiKey;
@property (nonatomic, copy, readwrite) NSURL *host;

@end


@implementation PHGPostHogConfiguration

+ (instancetype)configurationWithApiKey:(NSString *)apiKey
{
    return [[PHGPostHogConfiguration alloc] initWithApiKey:apiKey host:@"https://app.posthog.com"];
}

+ (instancetype)configurationWithApiKey:(NSString *)apiKey host:(NSString *)host
{
    return [[PHGPostHogConfiguration alloc] initWithApiKey:apiKey host:host];
}

- (instancetype)initWithApiKey:(NSString *)apiKey host:(NSString *)host
{
    if (self = [self init]) {
        self.apiKey = apiKey;
        self.host = [NSURL URLWithString:host];
    }
    return self;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.shouldUseLocationServices = NO;
        self.shouldUseBluetooth = NO;
        self.shouldSendDeviceID = YES;
        self.flushAt = 20;
        self.flushInterval = 30;
        self.maxQueueSize = 1000;
        self.libraryName = @"posthog-ios";
        self.libraryVersion = [PHGPostHog version];
        self.payloadFilters = @{
            @"(fb\\d+://authorize#access_token=)([^ ]+)": @"$1((redacted/fb-auth-token))"
        };
        Class applicationClass = NSClassFromString(@"UIApplication");
        if (applicationClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            _application = [applicationClass performSelector:NSSelectorFromString(@"sharedApplication")];
#pragma clang diagnostic pop
        }
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, [self dictionaryWithValuesForKeys:@[ @"apiKey", @"shouldUseLocationServices", @"flushAt" ]]];
}

@end
