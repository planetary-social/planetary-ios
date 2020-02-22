/*
 *
 *  ZDKJsonUtil.h
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

@interface ZDKJsonUtil : NSObject

/**
 * Checks the return value for NSNull and converts to nil if found.
 *
 * @param json the JSON dictionary from which to get the value
 * @param key the key of the object to be retrieved
 * @return the value if found and not NSNull, otherwise nil
 */
+ (id) cleanJSONVal:(NSDictionary*)json key:(NSString*)key;


/**
 * Check the value for NSNull.
 *
 * @param val the value to be checked
 * @return the value if not NSNull, otherwise nil
 */
+ (id) cleanJSONVal:(id)val;

/**
 * Checks the return value for NSNull and converts to an empty array if found.
 *
 * @param json the JSON dictionary from which to get the array
 * @param key the key of the object to be retrieved
 * @return the value if found and not NSNull, otherwise empty array
 */
+ (id) cleanJSONArrayVal:(NSDictionary*)json key:(NSString*)key;

/**
 *  Convert JSON based dictionary to an object of type Class
 *
 *  @param json       NSDictionary of JSON
 *  @param classToMap class to be converted to
 *
 *  @return instance of type class from JSON
 */
+ (id) convertJsonObject:(NSDictionary *)json toObjectOfType:(Class)classToMap;


/**
 *  Converts an array of json into an array of objects. The objects 
 *  in the return array will be instances of the class that was passed in.
 *
 *  @param jsonArray  An array of json objects
 *  @param classToMap The class to map the json objects to.
 *
 *  @return An array of objects.
 */
+ (NSMutableArray *) convertArrayOfJsonObjects:(NSArray *)jsonArray toArrayOfType:(Class)classToMap;


/**
 *  Generates a dictionary representation of a classes properties.
 *
 *  @param objectToConvert An instance of the class to convert.
 *  @param aClass          The class being converted.
 *
 *  @return A dictionary with the properties of a class keyed by the property names. 
 */
+ (NSDictionary *) convertObjectToDictionary:(id)objectToConvert forClass:(Class)aClass;

/**
 *  Fetch Array of properties of a class
 *
 *  @param aClass class to get properties for
 *
 *  @return NSMutableArray of properties for the class specified
 */
+ (NSMutableArray *)arrayWithPropertiesOfObject:(Class)aClass;

@end
