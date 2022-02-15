/*
 *
 *  ZDKTicketForm.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 25/07/2016.
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
#import <SupportProvidersSDK/ZDKDictionaryCreatable.h>


@class ZDKTicketField;

/**
 * Ticket form class
 *  @since 1.9.0.1
 */
@interface ZDKTicketForm : NSObject<ZDKDictionaryCreatable>

/**
 * Ticket form id
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSNumber *formId;

/**
 * Ticket form name for agents
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSString *name;

/**
 * Ticket form name for end users
 *  @since 1.9.1.1
 */
@property (nonatomic, copy) NSString *displayName;

/**
 * List of ticket field ids
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSArray<NSNumber*> *ticketFieldsIds;

/**
 * List of ticket field objects
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSArray<ZDKTicketField*> *ticketFields;

/**
 * Initialize a ticket form
 *  @since 1.9.0.1
 */
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

@end
