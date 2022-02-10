#import <Foundation/Foundation.h>
#import "PHGPostHog.h"

NS_ASSUME_NONNULL_BEGIN


@interface PHGHTTPClient : NSObject

@property (nonatomic, strong) PHGRequestFactory requestFactory;
@property (nonatomic, readonly) NSURLSession *session;
@property (nonatomic, weak)  id<NSURLSessionDelegate> httpSessionDelegate;

+ (PHGRequestFactory)defaultRequestFactory;

- (instancetype)initWithRequestFactory:(PHGRequestFactory _Nullable)requestFactory;

/**
 * This method will convert the dictionary to json, gzip it and upload the data.
 * It will respond with retry = YES if the batch should be reuploaded at a later time.
 * It will ask to retry for json errors and 3xx/5xx codes, and not retry for 2xx/4xx response codes.
 * NOTE: You need to re-dispatch within the completionHandler onto a desired queue to avoid threading issues.
 * Completion handlers are called on a dispatch queue internal to PHGHTTPClient.
 */
- (NSURLSessionUploadTask *)upload:(JSON_DICT)batch host:(NSURL *_Nonnull)host completionHandler:(void (^)(BOOL retry))completionHandler;

@end

NS_ASSUME_NONNULL_END
