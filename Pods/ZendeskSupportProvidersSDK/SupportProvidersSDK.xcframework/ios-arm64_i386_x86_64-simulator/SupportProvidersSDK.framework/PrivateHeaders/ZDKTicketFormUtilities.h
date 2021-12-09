/*
 *
 *  ZDKTicketFormUtilities.h
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


@class ZDKTicketField;
@class ZDKTicketForm;

@interface ZDKTicketFormUtilities : NSObject

+ (NSArray<NSNumber*>*)limitTicketFormIds:(NSArray<NSNumber*>*)ticketFieldsIds
                             toMaxCountOf:(NSInteger)ticketForms;

+ (void)mergeTicketFields:(NSArray<ZDKTicketField*>*)ticketFields
            inTicketForms:(NSArray<ZDKTicketForm*>*)ticketForms;

+ (NSArray*)parseArrayFromDictionary:(NSDictionary*)json
                                 key:(NSString*)key
                               class:(Class)theClass;

+ (BOOL)checkString:(NSString*)string matchesRegularExpression:(NSString*)regex;

@end
