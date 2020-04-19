/*
 *
 *  ZDKValdidator.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 28/07/2015.
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

/**
 *  Error domain for errors from ZDKPValidator
 */
extern NSString * const ZDKParameterValidationErrorDomain;

/**
 *  Validation error codes
 */
typedef NS_ENUM(NSUInteger, ZDKValidation){
    /**
     *  Nil value error code
     */
    ZDKValidationNilError,
    /**
     *  Empty string error code
     */
    ZDKValidationEmptyStringError,
};

/**
 *  @brief Convenience macro for using @p zdk_NilSafeNSDictionaryOfVariableBindings.
 *
 *  @see zdk_NilSafeNSDictionaryOfVariableBindings
 *
 *  @param ... List of variables to create a dictionary with.
 *
 *  @return A dictionary with the values of the variadic objects or NSNull with keys from the comma separated string.
 */
#define ZDKDictionaryWithNamesAndValues(...)  zdk_NilSafeNSDictionaryOfVariableBindings(@"" # __VA_ARGS__, __VA_ARGS__, nil)

/**
 *  @brief This function is a helper for validating method parameters with @p +validateValues:. The function takes
 *  a set of keys in a comma separated string, a variadic list of objects and returns a
 *  dictionary. Any nil objects in the variadic list are replaced with NSNull. The keys in the
 *  comma separated string are pair with the objects in the list i.e. the first key in the
 *  string is paired with the first variadic argument and so on.
 *
 *  @note This will crash hard if there are more keys in the string than objects passed in.
 *
 *  @param commaSeparatedKeysString A comma separated list of keys.
 *  @param first                    First object in the variadic list of objects.
 *  @param ...                      Remaining variadic objects.
 *
 *  @return A dictionary with the values of the variadic objects or NSNull with keys from the comma separated string.
 */
extern NSDictionary * zdk_NilSafeNSDictionaryOfVariableBindings(NSString *commaSeparatedKeysString, id first, ...);

@interface ZDKValidator : NSObject

/**
*  @brief This method takes a dictionary containing the values of parameters keyed by the
*  parameter names. There is a convenience macro which creates a dictionary in the expected
*  format.
*  
*  The method will check the parameters for an NSNull value and if they are a NSString that
*  is empty.
*
*  @param parameterDictionarys A dictionary containing the parameter names and values to be validated.
*
*  @return A nil value will be returned in the case of the parameterDictionarys passing both validation
*  checks in the method. If they fail a check, it will return an appropriate error.
*
*  @since 1.4.0.1
*/
+ (NSError *) validateValues:(NSDictionary *)parameterDictionarys;

@end
