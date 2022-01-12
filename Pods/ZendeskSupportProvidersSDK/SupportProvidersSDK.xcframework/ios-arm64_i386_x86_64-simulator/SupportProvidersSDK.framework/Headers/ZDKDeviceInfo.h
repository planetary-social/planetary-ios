/*
 *
 *  ZDKDeviceInfo.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 11/04/2014.  
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
#import <UIKit/UIKit.h>


/**
 * Helper class for retrieving device information.
 *
 *  @since 0.9.3.1
 */
@interface ZDKDeviceInfo : NSObject


/**
 *  Get a String of the device type, e.g. 'iPad 3 (WiFi)'
 *
 *  @since 0.9.3.1
 *
 *  @return the device type if recognized, the base OS device type string if not recognized.
 */
+ (NSString *) deviceType;


/**
 *  Get the total device memory.
 *
 *  @since 0.9.3.1
 *
 *  @return the device memory in GB
 */
+ (double) totalDeviceMemory;


/**
 *  Get the free disk space of the device.
 *
 *  @since 0.9.3.1
 *
 *  @return the free disk space of the device in GB
 */
+ (double) freeDiskspace;


/**
 *  Get the total disk space of the device.
 *
 *  @since 0.9.3.1
 *
 *  @return the total disk space of the device in GB
 */
+ (double) totalDiskspace;


/**
 *  The current battery level of the device.
 *
 *  @since 0.9.3.1
 *
 *  @return the current battery level of the device as a percentage
 */
+ (CGFloat) batteryLevel;


/**
 *  The current region setting of the device.
 *
 *  @since 0.9.3.1
 *
 *  @return the current region
 */
+ (NSString*) region;


/**
 *  The current language of the device
 *
 *  @since 0.9.3.1
 *
 *  @return the language
 */
+ (NSString*) language;


/**
 *  Returns an NSDictionary of all device info.
 *
 *  @since 1.0.0.1
 *
 *  @return all device info
 */
+ (NSDictionary*) deviceInfoDictionary;


@end
