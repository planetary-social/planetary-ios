/*
 *
 *  ZDKComment.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 13/06/2014.  
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
 * A comment on a Zendesk request.
 *
 *  @since 0.9.3.1
 */
@class ZDKAttachment;
@interface ZDKComment : NSObject

/**
 * The id of this comment in Zendesk.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, strong, readonly) NSNumber * commentId;

/**
 * The comment body/text.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *body;

/**
 * The HTML comment body/text.
 * Scrubbed for self-closing and unclosed tags, currently:
 * <br>
 * <br/>
 * <hr/>
 * <img>
 *
 * @since 2.0.0.0
 */
@property (nonatomic, copy) NSString *htmlBody;

/**
 * The Zendesk user id of the author.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, strong) NSNumber *authorId;

/**
 * The timestamp for the creation of this comment.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, strong) NSDate *createdAt;

/**
 *  Collection of ZDKAttachments associated with this comment.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSArray <ZDKAttachment *>* attachments;

/**
 *  The request the comment belongs to.
 *
 *  @since 1.4.1.1
 */
@property (nonatomic, copy) NSString *requestId;

/**
 * Initialise the model object with the account details ands the dispatcher to be used for requests.
 *
 *  @since 0.9.3.1
 *
 * @param dictionary the dictionary generated from the API json
 */
- (instancetype) initWithDictionary:(NSDictionary*)dictionary;

/**
 * Returns a dictionary with comment details. Used for storing a comment.
 *
 *  @since 2.0.0.1
 *
 * @return the dictionary generated from the API json
 */
- (NSDictionary *)toJson;

@end

