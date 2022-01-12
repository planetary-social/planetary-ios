/*
 *
 *  ZDKCommentsResponse.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 09/11/2014.  
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
 *  Collection model for comments.
 *
 *  @since 0.9.3.1
 */
@interface ZDKCommentsResponse : NSObject


/**
 *  Array of comments with users.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy, readonly) NSArray *commmentsWithUsers;


/**
 *  Parse data from an API and create an array of comments with users.
 *
 *  @since 0.9.3.1
 *
 *  @param dictionary JSON data from an API call.
 *
 *  @return An array of comments with users.
 */
+ (NSArray *) parseData:(NSDictionary *) dictionary;

@end
