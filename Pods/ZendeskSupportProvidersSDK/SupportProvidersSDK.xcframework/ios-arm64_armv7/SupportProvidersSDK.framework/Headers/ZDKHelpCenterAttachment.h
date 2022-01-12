/*
 *
 *  ZDKHelpCenterAttachment.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 25/09/2014.  
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

/**
 *  A model for Help Center Attachments.
 *
 *  @since 0.9.3.1
 */
@interface ZDKHelpCenterAttachment : NSObject

/**
 *  The id of an attachment.
 *
 *  @since 2.0.0
 */
@property (nonatomic, copy) NSNumber *identifier;

/**
 *  The url where the attachment can be found.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *url;

/**
 *  The id of the article for which an attachment belongs.
 *
 *  @since 2.0.0
 */
@property (nonatomic, copy) NSNumber *article_id;

/**
 *  The file name of an attachment.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *file_name;

/**
 *  Content url for an attachment.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *content_url;

/**
 *  The MIME type for an attachment.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *content_type;

/**
 *  Attachment file size.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, assign) NSUInteger size;

/**
 *  Is this an inline attachment?
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, assign) BOOL isInline;


/**
 *  Parses a single Help Center json attachment object.
 *
 *  @since 0.9.3.1
 *
 *  @return A new ZDKHelpCenterAttachment.
 */
+ (ZDKHelpCenterAttachment *) parseAttachment:(NSDictionary *)attachmentJson;


/**
 *  Parses a collection of Help Center json attachments objects.
 *
 *  @since 0.9.3.1
 *
 *  @param json JSON representation of attachments.
 *
 *  @return An array of Help Center attachment models.
 */
+ (NSArray *) parseAttachments:(NSDictionary *)json;


/**
 *  Returns a string human readable format of file size.
 *
 *  @since 0.9.3.1
 *
 *  @return human readable format of the file size.
 */
- (NSString *) humanReadableFileSize;


@end
