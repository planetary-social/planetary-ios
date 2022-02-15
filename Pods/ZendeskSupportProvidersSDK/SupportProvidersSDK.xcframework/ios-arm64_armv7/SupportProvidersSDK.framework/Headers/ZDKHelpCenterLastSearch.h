/*
 *
 *  ZDKHelpCenterLastSearch.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 15/05/2015.
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
 *  A model for recording the last search in Help Center.
 *
 *  @since 1.3.0.1
 */
@interface ZDKHelpCenterLastSearch : NSObject


/**
 * The last search query performed.
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, copy, readonly) NSString *query;


/**
 * The result count for the last search query.
 *
 *  @since 1.3.0.1
 */
@property (nonatomic, strong, readonly) NSNumber *results_count;


/**
 *  Create a new last search model.
 *
 *  @since 1.3.0.1
 *
 *  @param query The search query.
 *  @param count The results count.
 *
 *  @return A new instance.
 */
- (instancetype)initWithQuery:(NSString*)query resultsCount:(NSNumber*)count;


/**
 *  Get the json representation for this object.
 *
 *  @since 1.3.0.1
 *
 *  @return A dictionary with the property names as keys and property values as values.
 */
- (NSDictionary *) toJson;

@end
