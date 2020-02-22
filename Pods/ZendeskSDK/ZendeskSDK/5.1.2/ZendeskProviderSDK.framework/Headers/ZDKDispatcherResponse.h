/*
 *
 *  ZDKDispatcherResponse.h
 *  ZendeskSDK
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

/**
 *  A model for the responses from the dispatcher.
 *
 *  @since 0.9.3.1
 */
@interface ZDKDispatcherResponse : NSObject

/**
 *  The HTTP response from the request.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, strong) NSHTTPURLResponse *response;

/**
 *  The data from the request.
 *
 *  @since 0.9.3.1
 */
@property (nonatomic, strong) NSData *data;


/**
 *  Init a ZDKDispatcherResponse.
 *
 *  @since 0.9.3.1
 *
 *  @param response A HTTP response.
 *  @param data     Data from a HTTP response.
 *
 *  @return a new instance.
 */
- (instancetype) initWithResponse:(NSHTTPURLResponse*)response andData:(NSData*)data;


@end

