/*
 *
 *  ZDKHelpCenterArticleVote.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 5/19/15.
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


/**
 *  A Help Center Article Vote
 *
 *  @since 1.3.0.1
 */
@interface ZDKHelpCenterArticleVote : NSObject

/**
 *  Vote Id
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSNumber *identifier;

/**
 *  The API url of this vote
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSString *url;

/**
 *  The id of the user who casts the vote
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSNumber *userId;

/**
 *  The value of the vote
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSString *value;

/**
 *  The id of the item for which this vote was cast
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSNumber *itemId;

/**
 *  The type of the item. Can be "Article"
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSString *itemType;

/**
 *  The time at which the vote was created
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, strong) NSDate *createdAt;

/**
 *  The time at which the vote was last updated
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, strong) NSDate *updatedAt;

/**
 *  Parses a single Help Center Article Vote
 *
 *  @since 1.3.0.1
 *
 *  @return A new ZDKHelpCenterArticleVote.
 */
+ (ZDKHelpCenterArticleVote*) parseArticleVote:(NSDictionary*)articleVoteJson;

/**
 *  Parses a collection of Help Center Article Vote json objects
 *
 *  @since 1.3.0.1
 *
 *  @return An array of ZDKHelpCenterArticleVote objects
 */
+ (NSArray *) parseArticleVotes:(NSDictionary*)json;


@end
