/*
 *
 *  ZDKTicketFieldOption.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 22/07/2016.
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


/**
 * Ticket Field Option (for ZDKTicketFieldTypeTagger ticket field types)
 *  @since 1.9.0.1
 */
@interface ZDKTicketFieldOption : NSObject

/**
 * Ticket Field Option ID
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSNumber *fieldOptionId;

/**
 * Option Name
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSString *name;

/**
 * Option Value, passed to zendesk server
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSString *value;

/**
 * If isDefaultValue is true, then this option is the default selected one
 *  @since 1.9.0.1
 */
@property (nonatomic, assign) BOOL isDefaultValue;

/**
 * Initialize a ticket field with a dictionary
 *
 * @param dictionary The dictionary
 *
 * @return a ticket field option
 *
 *  @since 1.9.0.1
 */
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

@end
