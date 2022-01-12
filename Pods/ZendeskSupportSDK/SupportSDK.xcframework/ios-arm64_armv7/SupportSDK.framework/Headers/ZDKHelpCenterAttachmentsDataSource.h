/*
 *
 *  ZDKHelpCenterAttachmentsDataSource.h
 *  SupportSDK
 *
 *  Created by Zendesk on 07/11/2014.  
 *
 *  Copyright (c) 2014 Zendesk. All rights reserved.
 *
 *  By downloading or using the Zendesk Mobile SDK, You agree to the Zendesk Master
 *  Subscription Agreement https://www.zendesk.com/company/customers-partners/#master-subscription-agreement and Application Developer and API License
 *  Agreement https://www.zendesk.com/company/customers-partners/#application-developer-api-license-agreement and
 *  acknowledge that such terms govern Your use of and access to the Mobile SDK.
 *
 */

#import <SupportSDK/ZDKHelpCenterDataSource.h>


/**
 *  Data source for Help Center attachments.
 *
 *  @since 0.9.3.1
 */
@interface ZDKHelpCenterAttachmentsDataSource : ZDKHelpCenterDataSource


/**
 *  Initializes a data source with a cell identifier, configuration block and a provider.
 *
 *  @since 2.0.0
 *
 *  @param articleId The articleId passed as a String, the article to which attachments will be fetched.
 *
 *  @return A new instance.
 */
- (instancetype) initWithArticleId:(NSNumber *)articleId ;


@end
