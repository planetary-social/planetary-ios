/*
 *
 *  ZDKHelpCenterConversationsUIDelegate.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 11/11/2014.  
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
#import <ZendeskProviderSDK/ZDKNavBarConversationsUIType.h>
#import <UIKit/UIKit.h>

/**
 Used to select where conversations nav bar button will be active.
 - ZDKContactUsVisibilityArticleListAndArticle: The contact us nav bar button is visible in the article list and the article view.
 - ZDKContactUsVisibilityArticleListOnly: The contact us nav bar button is only visible in the article list.
 - ZDKContactUsVisibilityOff: The contact us nav bar button is not visible anywhere.
 */
__attribute__((deprecated("use ZDKHelpCenterUiConfiguration and ZDKArticleUiConfiguration to configure the 'contact us' button on their respective screens ")))
typedef NS_ENUM(NSUInteger, ZDKContactUsVisibility) {
    ZDKContactUsVisibilityArticleListAndArticle,
    ZDKContactUsVisibilityArticleListOnly,
    ZDKContactUsVisibilityOff,
};

__attribute__((deprecated("use ZDKHelpCenterUiConfiguration and ZDKArticleUiConfiguration to configure the 'contact us' button on their respective screens ")))
@protocol ZDKHelpCenterConversationsUIDelegate <NSObject>


/**
 *  To conform implementations should return the conversations UI type desired.
 *
 *  @return The ZDKNavBarConversationsUIType to display.
 */
- (ZDKNavBarConversationsUIType) navBarConversationsUIType;

/**
 *  Determines where the coversations nav bar button will be displayed.
 *
 *  @return a ZDKContactUsVisibility value.
 */
- (ZDKContactUsVisibility) active;

@optional

/**
 *  To conform implementations should return a localized string for the right nav bar button title.
 *
 *  @return A localized string for the right nav bar button.
 */
- (NSString *) conversationsBarButtonLocalizedLabel;

/**
 *  To conform implementations should return an image for the right nav bar button.
 *
 *  @return An image for the right nav bar button.
 */
- (UIImage *) conversationsBarButtonImage;

@end

__attribute__((deprecated("use ZDKHelpCenterUiConfiguration and ZDKArticleUiConfiguration to configure the 'contact us' button on their respective screens ")))
@protocol ZDKHelpCenterDelegate <NSObject>

@property (nonatomic, weak) id<ZDKHelpCenterConversationsUIDelegate> uiDelegate;

@end

