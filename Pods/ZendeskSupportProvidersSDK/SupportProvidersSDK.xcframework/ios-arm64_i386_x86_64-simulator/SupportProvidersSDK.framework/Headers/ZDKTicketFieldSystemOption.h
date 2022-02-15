/*
 *
 *  ZDKTicketFieldSystemOption.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 27/03/2017.
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
 * Ticket Field System Option (for `ZDKTicketFieldTypeStatus`, `ZDKTicketFieldTypePriority` and `ZDKTicketFieldTypeTicketType` ticket field types)
 *  @since 1.10.0.1
 */
@interface ZDKTicketFieldSystemOption : NSObject

/**
 * System Option Name
 *  @since 1.10.0.1
 */
@property (nonatomic, copy) NSString *name;

/**
 * System Option Value, passed to zendesk server
 *  @since 1.10.0.1
 */
@property (nonatomic, copy) NSString *value;

/**
 * Initialize a system ticket field option with a dictionary
 *
 * @param dictionary The dictionary
 *
 * @return a ticket field option
 *
 *  @since 1.10.0.1
 */
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

@end
