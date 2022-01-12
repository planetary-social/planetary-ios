/*
 *
 *  ZDKHelpCenterSearch.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 1/14/16
 *
 *  Copyright (c) 2015 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

#import <SupportProvidersSDK/ZDKHelpCenterSearch.h>


@interface ZDKHelpCenterSearch ()

/**
 *  This method will return a UTF-8 encoded query string based on the values of the properties of this class.
 *
 *  @param locale locale to use for query string
 *
 *  @return a UTF-8 encoded query string based on the values of the properties of this class.
 */
- (NSString *)queryStringWithLocale:(NSString*)locale;

/**
 *  Adds the parameters like categoryIds, sectionIds and labels from the ZDKHelpCenterContentModel
 *  and scopes a ZDKHelpCenterSearch to these parameters.
 *
 *  @param helpCenterContentModel A model that defines how the SDK Help Center is scoped and what
 *  articles, sections and categories to show.
 */
- (void)addSearchContentScope:(ZDKHelpCenterOverviewContentModel *)helpCenterContentModel;

@end
