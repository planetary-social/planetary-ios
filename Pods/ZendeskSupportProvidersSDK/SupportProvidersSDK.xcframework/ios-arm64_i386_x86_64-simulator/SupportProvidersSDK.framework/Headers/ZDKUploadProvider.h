/*
 *
 *  ZDKAttachmentProvider.h
 *  SupportProvidersSDK
 *
 *  Created by Zendesk on 13/01/2015.
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
#import <SupportProvidersSDK/ZDKUploadResponse.h>
#import <SupportProvidersSDK/ZDKProvider.h>


/**
 *  Block defined for callback to be used for handling async server responses for uploading an attachment.
 *
 *  @since 1.1.0.1
 *
 *  @param uploadResponse a response containing a ZDKAttachment and upload token.
 *  @param error          NSError returned as a result of any errors taking place when the request is executed, can be nil on success.
 */
typedef void (^ZDKUploadCallback)(ZDKUploadResponse *uploadResponse, NSError *error);

/**
 *  Block defined for callback to be used for handling async server responses for deleting an upload attachment.
 *
 *  @since 1.1.0.1
 *
 *  @param responseCode response code for a delete action.
 *  @param error        NSError returned as a result of any errors taking place when the request is executed, can be nil on success.
 */
typedef void (^ZDKDeleteUploadCallback)(NSString *responseCode, NSError *error);

/**
 *  A provider for uploading images to Zendesk which can then be attached to requests.
 *
 *  @since 1.1.0.1
 */
@interface ZDKUploadProvider : ZDKProvider

/**
 *  Upload an image to Zendesk, returns a token in the response that can be used to attach the file to a request.
 *
 *  @since 1.1.0.1
 *
 *  @param attachment    The attachment to upload
 *  @param filename      The file name you wan't to store the image as.
 *  @param contentType   The content type of the data, i.e: "image/png".
 *  @param callback      Block callback executed on request error or success.
 */
- (void) uploadAttachment:(NSData *)attachment
             withFilename:(NSString *)filename
           andContentType:(NSString*)contentType
                 callback:(ZDKUploadCallback)callback;


/**
 *  Delete an upload from Zendesk. Will only work if the upload has not been associated with a request/ticket.
 *
 *  @since 1.1.0.1
 *
 *  @param uploadToken Upload token of file to delete
 *  @param callback    Block callback executed on request error or success. Can be nil.
 */
- (void) deleteUpload:(NSString*)uploadToken
          andCallback:(ZDKDeleteUploadCallback)callback;


@end
