/*
 *
 *  ZDKCreateRequestUIDelegate.h
 *  SupportSDK
 *
 *  Created by Zendesk on 12/11/2014.  
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
 *  Enum to describe the types of nav bar button that display request creation.
 *
 *  @since 0.9.3.1
 */
typedef NS_ENUM(NSUInteger, ZDKNavBarCreateRequestUIType) {
    /**
     *  Nav bar button with localized label for request creation.
     *
     *  @since 0.9.3.1
     */
    ZDKNavBarCreateRequestUITypeLocalizedLabel,
    /**
     *  Nav bar button with image for request creation.
     *
     *  @since 0.9.3.1
     */
    ZDKNavBarCreateRequestUITypeImage,
};


/**
 *  Delegate for the create request view.
 *
 *  @since 0.9.3.1
 */
@protocol ZDKCreateRequestUIDelegate <NSObject>


/**
 *  To conform implementations should return the request creation UI type desired.
 *
 *  @since 0.9.3.1
 *
 *  @return The ZDKNavBarCreateRequestUIType to display.
 */
- (ZDKNavBarCreateRequestUIType) navBarCreateRequestUIType;


/**
 *  To conform implementations should return an image for the right nav bar button.
 *
 *  @since 0.9.3.1
 *
 *  @return An image for the right nav bar button.
 */
- (UIImage *) createRequestBarButtonImage;

/**
 *  To conform implementations should return a localized string for the right nav bar button title.
 *
 *  @since 0.9.3.1
 *
 *  @return A localized string for the right nav bar button.
 */
- (NSString *) createRequestBarButtonLocalizedLabel;

@end
