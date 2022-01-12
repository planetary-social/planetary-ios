/*
 *
 *  ZDKAttachmentProvider.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 10/11/2014.
 *
 *  Copyright (c) 2014 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

#import <Foundation/Foundation.h>
#import <SupportProvidersSDK/ZDKProvider.h>


/**
 *  Block invoked to pass data back from API call
 *
 *  @since 0.9.3.1
 *
 *  @param avatar UIImage of the response from server, can be nil on error
 *  @param error  NSError returned on during error state, can be nil on success
 */
typedef void (^ZDKAvatarCallback)(UIImage *avatar, NSError *error);

/**
 *  @since X.X.X.X
 */
typedef void (^ZDKDownloadCallback)(NSData *data, NSError *error);

/**
 *  Provider for images/avatars.
 *
 *  @since 0.9.3.1
 */
@interface ZDKAttachmentProvider : ZDKProvider

/**
 *  Get the image/avatar data for a given URL
 *
 *  @since 0.9.3.1
 *
 *  @param avatarUrl NSString url of the image to be fetched
 *  @param callback  block callback executed on error or success states
 */
- (void) getAvatarForUrl:(NSString *)avatarUrl withCallback:(ZDKAvatarCallback)callback;


/**
 *  @since X.X.X.X
 */
- (void) getAttachmentForUrl:(NSString *)attachmentUrl
                withCallback:(ZDKDownloadCallback)callback;

@end
