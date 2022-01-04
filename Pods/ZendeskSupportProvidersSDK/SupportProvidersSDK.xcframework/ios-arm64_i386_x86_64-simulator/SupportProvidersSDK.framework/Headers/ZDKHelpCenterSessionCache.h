/*
 *
 *  ZDKHelpCenterSessionCache.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 15/07/2015.
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

@class ZDKHelpCenterLastSearch;

@interface ZDKHelpCenterSessionCache : NSObject


/**
 *  Cache a search. This has the side effect of setting a unique search result click BOOL to yes.
 *
 *  @since 1.3.2.1
 *
 *  @param lastSearch The search to be cached.
 */
+ (void) cacheLastSearch:(ZDKHelpCenterLastSearch*)lastSearch;


/**
 *  Un-sets the unique search result click flag
 *
 *  @since 1.3.2.1
 */
+ (void) unsetUniqueSearchResultClick;


/**
 *  Get the last search
 *
 *  @return The last search, can be nil.
 *
 *  @since 1.3.3.1
 */
+ (ZDKHelpCenterLastSearch *)getLastSearch;


/**
 *  Used when submitting an article view with the Help Center provider.
 *
 *  @return A dictionary containing the last search model and a unique search result click. nil if no search has been preformed.
 *
 *  @since 1.3.2.1
 */
+ (NSDictionary *)recordArticleViewRequestJson;

@end
