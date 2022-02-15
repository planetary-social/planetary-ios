/*
 *
 *  ZDKBundleUtils.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 22/10/2014.
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
 *  Util for working with SupportSDK bundles.
 *
 *  @since 0.9.3.1
 */
@interface ZDKBundleUtils : NSObject


/**
 * Gets the framework resource bundle.
 *
 *  @since 0.9.3.1
 *
 * @return The frameworks resource NSBundle or nil if the SDK bundle was not found.
 */
+ (NSBundle *) frameworkResourceBundle;


/**
 * Gets the framework strings bundle.
 *
 *  @since 0.9.3.1
 *
 * @return The frameworks strings NSBundle or nil if the SDK bundle was not found.
 */
+ (NSBundle *) frameworkStringsBundle;


/**
 * Get the path for a resource in the SDK bundle.
 *
 *  @since 0.9.3.1
 *
 * @param name The resource name.
 * @param extension The file extension.
 * @return The path for the css file, or nil if file was not found.
 */
+ (NSString *) pathForFrameworkResource:(NSString *)name ofType:(NSString *)extension;


/**
 * Get the help center css file in the SDK bundle and return as a string.
 *
 *  @since 0.9.3.1
 *
 * @return A string containing css for help center.
 */
+ (NSString *) helpCenterCss;


/**
 * Get the help center css file in the host apps main bundle and return as a string.
 *
 * If you want your own style sheet for help center include a file named
 * help_center_article_style.css in your project and ensure it's included in the
 * Copy Bundle Resources build phase.
 *
 * @return A string containing css for help center.
 */
+ (NSString *) userDefinedHelpCenterCss;


/**
 *  The name of the frameworks strings table
 *
 *  @since 0.9.3.1
 *
 *  @return The string table name.
 */
+ (NSString *) stringsTableName;


/**
 *  Returns an image resource from SupportSDK bundle.
 *
 *  @since 1.1.0.1
 *
 *  @param name the name of the image.
 *  @param extension the extension of the image.
 *
 *  @return An image, or nil if the image was not found.
 */
+ (UIImage *) imageNamed:(NSString *)name ofType:(NSString *)extension;

@end
