#import <Foundation/Foundation.h>
#import "PHGSerializableValue.h"

NS_ASSUME_NONNULL_BEGIN


@interface PHGPayload : NSObject

@end


@interface PHGApplicationLifecyclePayload : PHGPayload

@property (nonatomic, strong) NSString *notificationName;

// ApplicationDidFinishLaunching only
@property (nonatomic, strong, nullable) NSDictionary *launchOptions;

@end


@interface PHGContinueUserActivityPayload : PHGPayload

@property (nonatomic, strong) NSUserActivity *activity;

@end


@interface PHGOpenURLPayload : PHGPayload

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSDictionary *options;

@end

NS_ASSUME_NONNULL_END


@interface PHGRemoteNotificationPayload : PHGPayload

// PHGEventTypeHandleActionWithForRemoteNotification
@property (nonatomic, strong, nullable) NSString *actionIdentifier;

// PHGEventTypeHandleActionWithForRemoteNotification
// PHGEventTypeReceivedRemoteNotification
@property (nonatomic, strong, nullable) NSDictionary *userInfo;

// PHGEventTypeFailedToRegisterForRemoteNotifications
@property (nonatomic, strong, nullable) NSError *error;

// PHGEventTypeRegisteredForRemoteNotifications
@property (nonatomic, strong, nullable) NSData *deviceToken;

@end
