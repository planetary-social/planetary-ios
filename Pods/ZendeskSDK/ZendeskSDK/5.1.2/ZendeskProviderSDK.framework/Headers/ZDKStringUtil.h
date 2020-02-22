/*
 *
 *  ZSKStringUtil.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 09/11/2014.
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

@interface ZDKStringUtil : NSObject

/**
 *  This method converts an array of strings into a comma separated string of the array's items. For example an array with 
 *  three items, "one", "two" and "three" will be converted into the string "one,two,three".
 *
 *  @param array An array of Strings to convert into a comma-separated string
 *  @return      A comma separated string of the items in the array or an empty string if there were none.
 */
+ (NSString*) csvStringFromArray:(NSArray*)array;

@end
