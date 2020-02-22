/*
 *
 *  ZDKAttachment.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 1/13/15.
 *
 *  Copyright (c) 2015 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

/**
 *  An attachment to a Zendesk comment
 */
@interface ZDKAttachment : NSObject

/**
 *  The id of this attachment in Zendesk.
 *
 *  @since 1.1.0.1
 */
@property (nonatomic, strong) NSNumber *attachmentId;

/**
 *  The name of the attachment in Zendesk.
 *
 *  @since 1.1.0.1
 */
@property (nonatomic, copy) NSString *filename;

/**
 *  The full url where the attachment can be downloaded.
 *
 *  @since 1.1.0.1
 */
@property (nonatomic, copy) NSString *contentURLString;

/**
 *  The content type of the attachment, i.e. image/png
 *
 *  @since 1.1.0.1
 */
@property (nonatomic, copy) NSString *contentType;

/**
 *  The size of the attachment in bytes.
 *
 *  @since 1.1.0.1
 */
@property (nonatomic, strong) NSNumber *size;

/**
 *  Thumbnails associated with the attachment. A thumbnail is an attachment with a nil thumbnails array.
 *
 *  @since 1.1.0.1
 */
@property (nonatomic, copy) NSArray <ZDKAttachment *>* thumbnails;

/**
 *  The dimension of the attachment.
 *
 *  @since 2.0.0.1
 */
@property (nonatomic, assign) CGSize imageDimension;

/**
 * Init with dictionary from API response.
 *
 *  @since 1.1.0.1
 *
 * @param dict the dictionary generated from the JSON API response
 */
- (instancetype) initWithDict:(NSDictionary*)dict;


@end
