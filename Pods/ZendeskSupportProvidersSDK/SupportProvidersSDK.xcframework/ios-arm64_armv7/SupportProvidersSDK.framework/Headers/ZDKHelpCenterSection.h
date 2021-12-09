/*
 *
 *  ZDKHelpCenterSection.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 25/09/2014.  
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


@interface ZDKHelpCenterSection : NSObject

/**
 *  Section id.
 *
 *  @since 2.0.0
 */
@property (nonatomic, copy) NSNumber *identifier;

/**
 *  Category id for section.
 *
 *  @since 2.0.0
 */
@property (nonatomic, copy) NSNumber *category_id;

/**
 *  section name.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *name;

/**
 *  Section Description.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, copy) NSString *sectionDescription;

/**
 *  Position in section list.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, assign) NSInteger position;

/**
 *  Current Locale.
 *
 *  @since 1.4.0.1
 */
@property (nonatomic, copy) NSString *locale;

/**
 *  Source Locale of the section
 *
 *  @since 1.4.0.1
 */
@property (nonatomic, copy) NSString *sourceLocale;

/**
 *  API url of the Section
 *
 *  @since 1.4.0.1
 */
@property (nonatomic, copy) NSString *url;

/**
 *  url of the Section in the help center
 *
 *  @since 1.4.0.1
 */
@property (nonatomic, copy) NSString *html_url;

/**
 *  Sorting type.
 *
 *  @since 1.4.0.1
 */
@property (nonatomic, copy) NSString *sorting;

/**
 *  Time at which the section was created at
 *
 *  @since 1.4.0.1
 */
@property (nonatomic, copy) NSString *createdAt;

/**
 *  Time at which the section was last updated at.
 *
 *  @since 1.4.0.1
 */
@property (nonatomic, copy) NSString *updatedAt;

/**
 *  Whether the section is outdated or not.
 *
 *  @since 1.4.0.1
 */
@property (nonatomic, assign) BOOL outdated;


/**
 * Parses a single Help Center json section object.
 *
 * @return A new ZDKHelpCenterSection.
 */
+ (ZDKHelpCenterSection *) parseSection:(NSDictionary *)sectionJson;


/**
 * Parses a collection of Help Center json section objects
 *
 */
+ (NSArray *) parseSections:(NSDictionary *)json;


@end
