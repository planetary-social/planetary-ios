/*
 *
 *  ZDKLocalization.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 06/04/2016.
 *
 *  Copyright (c) 2016 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDKLocalization : NSObject

/**
 *  Prints out every key in the SDK bundle. Use this if you want a complete 
 *  list of all the keys used in the SDK.
 */
+ (void)printAllKeys;

/**
 *  Use this method to register a non standard localized string table name.
 *  The standard name is "Localizabel.strings".
 *
 *  If, for example, you have a strings file called "MyStrings.strings", you
 *  should register "MyStrings" with this method. 
 *
 *  @param tableName The name of a strings file.
 */
+ (void)registerTableName:(NSString*)tableName;

/**
 *  Returns a localized value for the key provided. If a value is not found 
 *  this method will return the key which was provided. An empty string key will
 *  always result in an empty string for a value.
 *
 *  @param key A key which represents a localized value.
 *
 *  @return A localized string for the key provided.
 */
+ (NSString*)localizedStringWithKey:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
