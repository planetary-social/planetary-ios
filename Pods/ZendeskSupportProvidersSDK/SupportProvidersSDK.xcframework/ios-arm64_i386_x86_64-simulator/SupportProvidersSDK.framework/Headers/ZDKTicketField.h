/*
 *
 *  ZDKTicketField.h
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
#import <SupportProvidersSDK/ZDKDictionaryCreatable.h>


/**
 * Ticket field type
 *  @since 1.9.0.1
 */
typedef NS_ENUM(NSUInteger, ZDKTicketFieldType) {
    /**
     * Ticket field regular expression type
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeSubject,
    /**
     * Ticket field regular expression type
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeDescription,
    /**
     * Ticket field regular expression type
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeRegex,
    /**
     * Ticket field text area type that allows multi-line text
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeTextArea,
    /**
     * Ticket field text type that allows single-line text
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeText,
    /**
     * Ticket field check box type
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeCheckbox,
    /**
     * Ticket field combobox type (Combobox)
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeComboBox,
    /**
     * Ticket field integer box type
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeInteger,
    /**
     * Ticket field decimal box type
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeDecimal,
    /**
     * Ticket field date selection type
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeDate,
    /**
     * Ticket field credit card type
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeCreditCard,
    /**
     * Ticket field priority system type
     *  @since 1.10.0.1
     */
    ZDKTicketFieldTypePriority,
    /**
     * Ticket field status system type
     *  @since 1.10.0.1
     */
    ZDKTicketFieldTypeStatus,
    /**
     * Ticket field ticket system type
     *  @since 1.10.0.1
     */
    ZDKTicketFieldTypeTicketType,
    /**
     * Ticket field ticket system type
     *  @since 1.10.0.1
     */
    ZDKTicketFieldTypeMultiSelect,
    /**
     * Ticket field unknown
     *  @since 1.9.0.1
     */
    ZDKTicketFieldTypeUnknown = NSUIntegerMax,
};




@class ZDKTicketFieldOption, ZDKTicketFieldSystemOption;


/**
 * Ticket field class
 *  @since 1.9.0.1
 */
@interface ZDKTicketField : NSObject<ZDKDictionaryCreatable>

/**
 * The ticket field ID
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSNumber *fieldId;

/**
 * Ticket field title
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSString *title;

/**
 * Ticket field title in portal
 *  @since 1.9.1.1
 */
@property (nonatomic, copy) NSString *titleInPortal;

/**
 * Ticket field english description
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSString *fieldDescription;

/**
 * Ticket field validation regular expression
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSString *validationRegex;

/**
 * Ticket field type
 *  @since 1.9.0.1
 */
@property (nonatomic, assign) ZDKTicketFieldType type;

/**
 * Ticket field requiry status
 *  @since 1.9.0.1
 */
@property (nonatomic, assign) BOOL required;

/**
 * Ticket field options, this field will only be populated for `ZDKTicketFieldTypeComboBox` field types
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSArray<ZDKTicketFieldOption*> *options;

/**
 * Ticket field system options, this field will only be populated for `ZDKTicketFieldTypeStatus`, `ZDKTicketFieldTypePriority` and `ZDKTicketFieldTypeTicketType` field types
 *  @since 1.9.0.1
 */
@property (nonatomic, copy) NSArray<ZDKTicketFieldSystemOption*> *systemOptions;

/**
 * Initialize a ticket field with a dictionary
 *
 * @param dictionary The dictionary
 *
 * @return a ticket field
 *
 *  @since 1.9.0.1
 */
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

@end
