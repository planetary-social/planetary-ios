/*
 *
 *  ZDKRequestWithAttachmentsUtil.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 1/26/15.
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
#import "ZDKUploadProvider.h"
#import "ZDKRequestProvider.h"

@class ZDKComment, ZDKRequest;


@interface ZDKRequestWithAttachmentsUtil : NSObject


/**
 *  Upload a file to Zendesk, provider wrapper.
 *
 *  @param data        Data to upload.
 *  @param filename    The filename.
 *  @param callback    Callback executed after request completes.
 */
- (void)uploadAttachment:(NSData *)data
            withFilename:(NSString *)filename
                callback:(ZDKUploadCallback)callback;

/**
 *  Upload a file to Zendesk, provider wrapper.
 *
 *  @param data        Data to upload.
 *  @param filename    The filename.
 *  @param contentType MIME type.
 *  @param callback    Callback executed after request completes.
 */
- (void) uploadAttachment:(NSData*)data
             withFilename:(NSString*)filename
           andContentType:(NSString*)contentType
                 callback:(ZDKUploadCallback)callback;

/**
 *  Create a request in Zendesk. If there are uploads in progress this call waits
 *  for them to finish. It will then attach the completed upload tokens to the request.
 *  Note: It is expected that separate instances of this class will be used when sending comments
 *  and requests.
 *
 *  @param request  The request description field.
 *  @param tags     Request tags.
 *  @param callback Callback executed after request completes.
 */
- (void) createRequest:(ZDKRequest*)request
              withTags:(NSArray*)tags
           andCallback:(ZDKCreateRequestCallback)callback;

/**
 *  Add a comment to a request in Zendesk. If there are uploads in progress this call waits
 *  for them to finish. It will then attach the completed upload tokens to the request.
 *  Note: It is expected that separate instances of this class will be used when sending comments
 *  and requests.
 *
 *  @param comment   Comment description field.
 *  @param requestId The ID of the request to add the comment too.
 *  @param callback  Callback executed after request returns.
 */
- (void)addComment:(ZDKComment *)comment
      forRequestId:(NSString *)requestId
      withCallback:(ZDKRequestAddCommentCallback)callback;


/**
 *  Delete a file that has been uploaded. Files can be deleted at anytime before they have
 *  been associated with a comment or request.
 *
 *  @param filename The filename to delete.
 */
- (void) deleteFilename:(NSString*)filename;


/**
 *  Mime-type for NSData, only supports images.
 *
 *  @param data Data to determine type of.
 *
 *  @return MIME type as string.
 */
+ (NSString *) MIMETypeForData:(NSData*)data;


@end
