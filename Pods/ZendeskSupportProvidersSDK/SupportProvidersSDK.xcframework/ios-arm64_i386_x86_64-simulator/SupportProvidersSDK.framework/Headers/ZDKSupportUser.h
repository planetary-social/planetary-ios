/*
 *
 *  ZDKUser.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 13/06/2014.  
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

@interface ZDKSupportUser : NSObject

@property (nonatomic, strong) NSNumber *userId;

@property (nonatomic, copy) NSString *name;

@property (nonatomic, copy) NSString *avatarURL;

@property (nonatomic, assign) BOOL isAgent;

@property (nonatomic, copy) NSArray *tags;

@property (nonatomic, copy) NSDictionary *userFields;

- (instancetype) initWithDictionary:(NSDictionary*)dictionary;

- (NSDictionary *)toJson;

@end

