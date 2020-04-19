/*
 *
 *  ZDKToastViewWrapper.h
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

#import <UIKit/UIKit.h>


@interface ZDKToastViewWrapper : UIView

@property (nonatomic, readonly) BOOL isVisible;

- (void)showErrorInViewController:(UIViewController*)viewController
                      withMessage:(NSString*)message;

- (void)showErrorInViewController:(UIViewController*)viewController
                      withMessage:(NSString*)message
                         duration:(CGFloat)duration;

- (void)showErrorInViewController:(UIViewController*)viewController
                      withMessage:(NSString*)message
                      buttonTitle:(NSString*)buttonTitle
                           action:(void (^)(void))action;

- (void)dismiss;

- (void)hideToastView:(BOOL)hide;

@end
