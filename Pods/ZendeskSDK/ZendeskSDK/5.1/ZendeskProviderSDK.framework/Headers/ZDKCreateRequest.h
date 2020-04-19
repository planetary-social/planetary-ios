/*
 *
 *  ZDKCreateRequest.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 5/22/15.
 *
 *  Copyright (c) 2015 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

#import <Foundation/Foundation.h>
@class ZDKCustomField;

/**
 *  A request sent by the user.
 *
 *  @since 1.3.0.1
 */
@interface ZDKCreateRequest : NSObject


/**
 *  List of tags associated with the request
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSArray *tags;

/**
 *  The subject of the request, if subject is enabled in the account.
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSString *subject;

/**
 *  The body of the request
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSString *requestDescription;



/**
 *  List of ZDKUploadResponse objects.
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSArray *attachments;


/**
 *  An array for custom fields.
 *
 *  @see <a href="https://developer.zendesk.com/embeddables/docs/ios/providers#using-custom-fields-and-custom-forms">Custom fields and forms documentation</a>
 *
 *  @since 4.0.0
 */
@property (nonatomic, copy) NSArray<ZDKCustomField*> *customFields;


/**
 *  Form id for ticket creation.
 *
 *  The ticket form id will be ignored if your Zendesk doesn't support it.  Currently
 *  Enterprise and higher plans support this.
 *
 *  @see <a href="https://developer.zendesk.com/embeddables/docs/ios/providers#using-custom-fields-and-custom-forms">Custom fields and forms documentation</a>
 *
 *  @since 1.6.0.1
 */
@property (nonatomic, strong) NSNumber *ticketFormId;


/**
 *  Init with dictionary
 *
 *  @param dict Data dictionary. Has the same structure as presented by this model object.
 *
 *  @since 1.3.0.1
 */
- (instancetype) initWithDict:(NSDictionary*)dict;



@end
