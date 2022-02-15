#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "PHGAES256Crypto.h"
#import "PHGCrypto.h"
#import "NSData+PHGGZIP.h"
#import "PHGFileStorage.h"
#import "PHGHTTPClient.h"
#import "PHGMacros.h"
#import "PHGPostHogIntegration.h"
#import "PHGPostHogUtils.h"
#import "PHGStorage.h"
#import "PHGStoreKitCapturer.h"
#import "PHGUserDefaultsStorage.h"
#import "PHGUtils.h"
#import "UIViewController+PHGScreen.h"
#import "PHGContext.h"
#import "PHGMiddleware.h"
#import "PHGAliasPayload.h"
#import "PHGCapturePayload.h"
#import "PHGIdentifyPayload.h"
#import "PHGPayload.h"
#import "PHGPayloadManager.h"
#import "PHGScreenPayload.h"
#import "PHGIntegration.h"
#import "PHGPostHog.h"
#import "PHGPostHogConfiguration.h"
#import "PHGSerializableValue.h"
#import "ObjC.h"
#import "PHGReachability.h"

FOUNDATION_EXPORT double PostHogVersionNumber;
FOUNDATION_EXPORT const unsigned char PostHogVersionString[];

