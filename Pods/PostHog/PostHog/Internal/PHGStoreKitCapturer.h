#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "PHGPostHog.h"

NS_ASSUME_NONNULL_BEGIN


@interface PHGStoreKitCapturer : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (instancetype)captureTransactionsForPostHog:(PHGPostHog *)posthog;

@end

NS_ASSUME_NONNULL_END
