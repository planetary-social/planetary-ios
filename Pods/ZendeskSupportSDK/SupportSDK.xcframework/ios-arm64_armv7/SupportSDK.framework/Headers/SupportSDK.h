/*
 *
 *  SupportSDK.h
 *  SupportSDK
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

#ifndef SupportSDK_h
#define SupportSDK_h


#import <SupportSDK/ZDKCreateRequestUIDelegate.h>
#import <SupportSDK/ZDKHelpCenterArticleRatingHandlerProtocol.h>
#import <SupportSDK/ZDKHelpCenterAttachmentsDataSource.h>
#import <SupportSDK/ZDKHelpCenterConversationsUIDelegate.h>
#import <SupportSDK/ZDKHelpCenterDataSource.h>
#import <SupportSDK/ZDKHelpCenterErrorCodes.h>
#import <SupportSDK/ZDKHelpCenterUi.h>
#import <SupportSDK/ZDKLayoutGuideApplicator.h>
#import <SupportSDK/ZDKSpinnerDelegate.h>
#import <SupportSDK/ZDKSupportAttachmentCell.h>
#import <SupportSDK/ZDKToastViewWrapper.h>
#import <SupportSDK/ZDKUIUtil.h>

#if MODULES_DISABLED
#import <SupportProvidersSDK/SupportProvidersSDK.h>
#else
@import SupportProvidersSDK;
#endif

#endif
