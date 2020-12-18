#import "PHGHTTPClient.h"
#import "NSData+PHGGZIP.h"
#import "PHGPostHogUtils.h"


@implementation PHGHTTPClient

+ (NSMutableURLRequest * (^)(NSURL *))defaultRequestFactory
{
    return ^(NSURL *url) {
        return [NSMutableURLRequest requestWithURL:url];
    };
}

- (instancetype)initWithRequestFactory:(PHGRequestFactory)requestFactory
{
    if (self = [self init]) {
        if (requestFactory == nil) {
            self.requestFactory = [PHGHTTPClient defaultRequestFactory];
        } else {
            self.requestFactory = requestFactory;
        }
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPAdditionalHeaders = @{
            @"Accept-Encoding" : @"gzip",
            @"Content-Encoding" : @"gzip",
            @"Content-Type" : @"application/json",
            @"User-Agent" : [NSString stringWithFormat:@"posthog-ios/%@", [PHGPostHog version]],
        };
        _session = [NSURLSession sessionWithConfiguration:config delegate:_httpSessionDelegate delegateQueue:NULL];
    }
    return self;
}

- (void)dealloc
{
    [self.session finishTasksAndInvalidate];
}

- (NSURLSessionUploadTask *)upload:(NSDictionary *)batch host:(NSURL *)host completionHandler:(void (^)(BOOL retry))completionHandler
{
    NSURLSession *session = self.session;
    NSURL *url = [host URLByAppendingPathComponent:@"batch"];
    NSMutableURLRequest *request = self.requestFactory(url);

    // This is a workaround for an IOS 8.3 bug that causes Content-Type to be incorrectly set
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [request setHTTPMethod:@"POST"];

    NSError *error = nil;
    NSException *exception = nil;
    NSData *payload = nil;
    @try {
        payload = [NSJSONSerialization dataWithJSONObject:batch options:0 error:&error];
    }
    @catch (NSException *exc) {
        exception = exc;
    }
    if (error || exception) {
        PHGLog(@"Error serializing JSON for batch upload %@", error);
        completionHandler(NO); // Don't retry this batch.
        return nil;
    }
    NSData *gzippedPayload = [payload phg_gzippedData];

    NSURLSessionUploadTask *task = [session uploadTaskWithRequest:request fromData:gzippedPayload completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error) {
            // Network error. Retry.
            PHGLog(@"Error uploading request %@.", error);
            completionHandler(YES);
            return;
        }

        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code < 300) {
            // 2xx response codes. Don't retry.
            completionHandler(NO);
            return;
        }
        if (code < 400) {
            // 3xx response codes. Retry.
            PHGLog(@"Server responded with unexpected HTTP code %d.", code);
            completionHandler(YES);
            return;
        }
        if (code == 429) {
          // 429 response codes. Retry.
          PHGLog(@"Server limited client with response code %d.", code);
          completionHandler(YES);
          return;
        }
        if (code < 500) {
            // non-429 4xx response codes. Don't retry.
            PHGLog(@"Server rejected payload with HTTP code %d.", code);
            completionHandler(NO);
            return;
        }

        // 5xx response codes. Retry.
        PHGLog(@"Server error with HTTP code %d.", code);
        completionHandler(YES);
    }];
    [task resume];
    return task;
}
@end
