/*
 *
 *  ZDKHelpCenterOverviewContentModel+Private.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 18/07/2016.
 *
 *  Copyright © 2016 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

#import <SupportProvidersSDK/ZDKHelpCenterOverviewContentModel.h>

@interface ZDKHelpCenterOverviewContentModel (Private)

@property (nonatomic, strong) NSNumber *initialNumberOfArticles;

- (NSString *)formQueryString;

@end
