/*
 *
 *  ZDKHelpCenterDeflection.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 3/26/15.
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
 *  This class models a Help Center Deflection search. It has the same contract as a normal Help Center search.
 *  https://developer.zendesk.com/rest_api/docs/help_center/search
 *  @since 1.2.0.1
 */
@interface ZDKHelpCenterDeflection : NSObject

/**
 *  This models the free-form text query.
 *  @since 1.2.0.1
 */
@property (nonatomic, copy) NSString *query;

/**
 *  This models the "label_names" parameter. This will be a comma-separated list of label names to restrict the search to.
 *  @since 1.2.0.1
 */
@property (nonatomic, copy) NSMutableArray *labelNames;

/**
 *  This models the "locale" parameter. This specifies that the search will be restricted to content with this locale.  The locale
 *  is in the format of "ll-cc", e.g. "en-us".  Locales in the form of "ll" are also permitted, e.g. "en".
 *  @since 1.2.0.1
 */
@property (nonatomic, copy) NSString *locale;

/**
 *  This models the "include" parameter.  This specifies the elements to side-load and include in the results.
 *  @since 1.2.0.1
 */
@property (nonatomic, copy) NSMutableArray *sideLoads;

/**
 *  This models the "category" parameter.  This specifies that the search will be restricted to content that is in the given
 *  category.
 *  @since 1.2.0.1
 */
@property (nonatomic, strong) NSNumber *categoryId;

/**
 *  This models the "section" parameter.  This specifies that the search will be restricted to content that is in the given
 *  section.
 *  @since 1.2.0.1
 */
@property (nonatomic, strong) NSNumber *sectionId;

/**
 *  This models the "page" parameter. This specifies what page of results to return.  This is closely tied to the resultsPerPage
 *  property.
 *  @since 1.2.0.1
 */
@property (nonatomic, strong) NSNumber *page;

/**
 *  This models the "per_page" parameter.  This specifies how many results to return for the current page.  The current page is
 *  specified by the page property.
 *  @since 1.2.0.1
 */
@property (nonatomic, strong) NSNumber *resultsPerPage;


@end

