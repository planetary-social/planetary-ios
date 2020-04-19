/*
 *
 *  ZDKHelpCenterArticle.h
 *  ZendeskSDK
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
 *  A Help Center Article.
 *
 *  @since 0.9.3.1
 */
@interface ZDKHelpCenterArticle : NSObject

/**
 *  Article id.
 *
 *  @since 2.0.0
 */
@property (nonatomic, copy) NSNumber *identifier;

/**
 *  Section id.
 *
 *  @since 2.0.0
 */
@property (nonatomic, copy) NSNumber *section_id;

/**
 *  Article title.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *title;

/**
 *  Content of the article.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *body;


/**
 *  Author of the article.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *author_name;

/**
 *  Id of the author.
 *
 *  @since 2.0.0
 */
@property (nonatomic, copy) NSNumber *author_id;

/**
 *  A string containing the category and section an article belongs to. This can be nil.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *articleParents;

/**
 *  Creation date for an article.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, strong) NSDate *created_at;

/**
 *  The articles position in it's parent section.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, assign) NSInteger position;

/**
 *  Is the article outdated?
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, assign) BOOL outdated;

/**
 *  The total sum of votes on this article.
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, strong) NSNumber *voteSum;

/**
 *  The number of votes cast on this article.
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, strong) NSNumber *voteCount;

/**
 *  The locale of this article
 * 
 *  @since 1.3.0.1
 */
@property (nonatomic, copy) NSString *locale;

/**
 *  An array of label names associated with the article.
 *
 *  @since 1.6.0.1
 */
@property (nonatomic, copy) NSArray *labelNames;

/**
 *  This is the URL that can be used to open the article in a browser.
 *
 *  @since 1.10.0.1
 */
@property (nonatomic, copy) NSString *htmlUrl;

/**
 *  Gets the number of upvotes for this article.
 *
 *  @since 1.3.0.1
 *
 *  @return The number of upvotes for this article or -1 if the number of votes cannot be determined due to an error
 */
- (NSInteger) getUpvoteCount;

/**
 *  Get the number of downvotes for this article.
 *
 *  @since 1.3.0.1
 *
 *  @return The number of downvotes for this article or -1 if the number of votes cannot be determined due to an error.
 */
- (NSInteger) getDownvoteCount;


/**
 *  Parses a single Help Center json article object.
 *
 *  @since 0.9.3.1
 *
 *  @return A new ZDKHelpCenterArticle.
 */
+ (ZDKHelpCenterArticle *) parseArticle:(NSDictionary *)articleJson;


@end
