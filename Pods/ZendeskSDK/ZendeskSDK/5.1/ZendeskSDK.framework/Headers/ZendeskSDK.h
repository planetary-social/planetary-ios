/*
 *
 *  ZendeskSDK.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 06/12/2018
 *
 *  Copyright (c) 2018 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

#import <UIKit/UIKit.h>

#ifndef ZendeskSDK_h
#define ZendeskSDK_h


#import "ZDKCreateRequestUIDelegate.h"
#import "ZDKHelpCenterArticleRatingHandlerProtocol.h"
#import "ZDKHelpCenterAttachmentsDataSource.h"
#import "ZDKHelpCenterConversationsUIDelegate.h"
#import "ZDKHelpCenterDataSource.h"
#import "ZDKHelpCenterErrorCodes.h"
#import "ZDKHelpCenterUi.h"
#import "ZDKLayoutGuideApplicator.h"
#import "ZDKSpinnerDelegate.h"
#import "ZDKSupportAttachmentCell.h"
#import "ZDKToastViewWrapper.h"
#import "ZDKUIUtil.h"

#if MODULES_DISABLED
#import <ZendeskProviderSDK/ZendeskProviderSDK.h>
#else
@import ZendeskProviderSDK;
#endif

#endif
