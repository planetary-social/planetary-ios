/*
 *
 *  ZDKAPIDispatcher.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on  24/12/2015.
 *
 *  Copyright (c) 2016 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

#import <Foundation/Foundation.h>
#import "ZDKDispatcher.h"
#import "ZendeskSDKConstants.h"


@class ZDKZendesk;

@interface ZDKAPIDispatcher : NSObject

+ (instancetype)instanceWithZendesk:(ZDKZendesk *)zendesk;

- (void)executeRequest:(NSMutableURLRequest* (^)(void))requestBlock
             onSuccess:(ZDKAPISuccess)successBlock
               onError:(ZDKAPIError)errorBlock
          requiresAuth:(BOOL)requiresAuth;

+ (void)resetSession;

@end
