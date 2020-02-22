/*
 *
 *  ZDKHelpCenterSearch.h
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
 *  This class models a Help Center search.  For more details about Help Centre search please see:
 *  https://developer.zendesk.com/rest_api/docs/help_center/search
 */
@interface ZDKHelpCenterSearch : NSObject

/**
 *  This models the free-form text query
 */
@property (nonatomic, copy) NSString *query;

/**
 *  This models the "label_names" parameter. This will be a comma-separated list of label names to restrict the search to.
 */
@property (nonatomic, copy) NSMutableArray *labelNames;

/**
 *  This models the "locale" parameter. This specifies that the search will be restricted to content with this locale.  The locale
 *  is in the format of "ll-cc", e.g. "en-us".  Locales in the form of "ll" are also permitted, e.g. "en".
 */
@property (nonatomic, copy) NSString *locale;

/**
 *  This models the "include" parameter.  This specifies the elements to side-load and include in the results.
 */
@property (nonatomic, copy) NSMutableArray *sideLoads;

/**
 *  This models the "category" parameter.  This specifies that the search will be restricted to content that is in the given
 *  array of categories.
 */
@property (nonatomic, copy) NSArray<NSNumber *> *categoryIds;

/**
 *  This models the "section" parameter.  This specifies that the search will be restricted to content that is in the given
 *  array of sections.
 */
@property (nonatomic, copy) NSArray<NSNumber *> *sectionIds;

/**
 *  This models the "page" parameter. This specifies what page of results to return.  This is closely tied to the resultsPerPage
 *  property.
 */
@property (nonatomic, strong) NSNumber *page;

/**
 *  This models the "per_page" parameter.  This specifies how many results to return for the current page.  The current page is
 *  specified by the page property.
 */
@property (nonatomic, strong) NSNumber *resultsPerPage;


@end
