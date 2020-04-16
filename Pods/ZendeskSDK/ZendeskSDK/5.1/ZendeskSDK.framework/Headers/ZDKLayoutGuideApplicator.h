/*
 *
 *  ZDKLayoutGuideApplicator.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on  22/12/2015
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
#import <UIKit/UIKit.h>


/**
 *  Layout guides positions to fix
 */
typedef NS_ENUM(NSUInteger, ZDKLayoutGuideApplicatorPosition) {
    /**
     *  Fix the top guide layout position
     */
    ZDKLayoutGuideApplicatorPositionTop,
    /**
     *  Fix the bottom guide layout position
     */
    ZDKLayoutGuideApplicatorPositionBottom,
};


NS_ASSUME_NONNULL_BEGIN

/**
 This class tries to fix the layout spacing when using XIB instead of storyboard.
 Since we cannot reference the top/bottom layout guids. This class fixes the top/bottom layout to be relative to the guides.
 */
@interface ZDKLayoutGuideApplicator : NSObject

/**
 *  Creates an instance
 *
 *  @param viewController the viewcontroller containing the view to fix the layout for
 *  @param topLevelView   the view that is closest to the parent y origin.
 *  @param position       positions to fix
 */
- (instancetype)initWithViewController:(UIViewController  *)viewController
                          topLevelView:(UIView *)topLevelView
                        layoutPosition:(ZDKLayoutGuideApplicatorPosition)position NS_DESIGNATED_INITIALIZER;

- (instancetype )init NS_UNAVAILABLE;

@end
NS_ASSUME_NONNULL_END
