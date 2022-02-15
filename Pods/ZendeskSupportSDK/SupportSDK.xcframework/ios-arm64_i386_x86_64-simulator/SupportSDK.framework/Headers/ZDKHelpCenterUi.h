/*
 *
 *  ZDKHelpCenterUi.h
 *  SupportSDK
 *
 *  Created by Zendesk on 15/03/2018.
 *
 *  Copyright (c) 2018 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */


#import <UIKit/UIKit.h>

#import <SupportSDK/ZDKHelpCenterConversationsUIDelegate.h>

@protocol ZDKConfiguration;

@class ZDKHelpCenterArticle;

NS_ASSUME_NONNULL_BEGIN


@interface ZDKHelpCenterUi : NSObject

/**
 * Build the Help Center Overview view controller. Displays an overview of your HelpCenter
 *
 *  @since 2.3.0
 */
+ (UIViewController *) buildHelpCenterOverviewUi;

+ (UIViewController <ZDKHelpCenterDelegate>*) buildHelpCenterOverview __attribute__((deprecated("use buildHelpCenterOverviewUi instead")));

/**
 * Build the Help Center Overview view controller with a list of ZDKConfigurations.
 *
 *  @param configs A list of ZDKConfigurations.
 *
 *  @since 2.3.0
 */
+ (UIViewController *) buildHelpCenterOverviewUiWithConfigs:(NSArray<id <ZDKConfiguration>> *)configs;

+ (UIViewController <ZDKHelpCenterDelegate>*) buildHelpCenterOverviewWithConfigs:(NSArray<id <ZDKConfiguration>> *)configs __attribute__((deprecated("use buildHelpCenterOverviewUiWithConfigs instead")));

/**
 * Build the Help Center Article view controller. Displays a single article.
 *
 *  @param article A ZDKHelpCenterArticle to display.
 *
 *  @since 2.3.0
 */
+ (UIViewController *) buildHelpCenterArticleUi:(ZDKHelpCenterArticle *)article;

+ (UIViewController<ZDKHelpCenterDelegate>*) buildHelpCenterArticle:(ZDKHelpCenterArticle *)article __attribute__((deprecated("use buildHelpCenterArticleUi instead")));

/**
 * Build the Help Center Article view controller. Displays a single article.
 *
 *  @param article A ZDKHelpCenterArticle to display.
 *  @param configs A list of ZDKConfigurations.
 *
 *  @since 2.3.0
 */
+ (UIViewController *) buildHelpCenterArticleUi:(ZDKHelpCenterArticle *)article
                                     andConfigs:(NSArray<id <ZDKConfiguration>> *)configs;

+ (UIViewController<ZDKHelpCenterDelegate>*) buildHelpCenterArticle:(ZDKHelpCenterArticle *)article
                                                         andConfigs:(NSArray<id <ZDKConfiguration>> *)configs __attribute__((deprecated("use buildHelpCenterArticleUi:andConfigs instead")));

/**
 * Build the Help Center Article view controller. Displays a single article.
 *
 *  @param articleId The ID of a Help Center article. This is fetched and displayed.
 *
 *  @since 2.3.0
 */
+ (UIViewController *) buildHelpCenterArticleUiWithArticleId:(NSString *)articleId;

+ (UIViewController<ZDKHelpCenterDelegate>*) buildHelpCenterArticleWithArticleId:(NSString *)articleId __attribute__((deprecated("use buildHelpCenterArticleUiWithArticleId instead")));

/**
 * Build the Help Center Article view controller. Displays a single article.
 *
 *  @param articleId The ID of a Help Center article. This is fetched and displayed.
 *  @param configs A list of ZDKConfigurations.
 *
 *  @since 2.3.0
 */
+ (UIViewController *) buildHelpCenterArticleUiWithArticleId:(NSString *)articleId
                                                  andConfigs:(NSArray<id <ZDKConfiguration>> *)configs;

+ (UIViewController<ZDKHelpCenterDelegate>*) buildHelpCenterArticleWithArticleId:(NSString *)articleId
                                                                      andConfigs:(NSArray<id <ZDKConfiguration>> *)configs __attribute__((deprecated("use buildHelpCenterArticleUiWithArticleId:andConfigs instead")));


@end

NS_ASSUME_NONNULL_END
