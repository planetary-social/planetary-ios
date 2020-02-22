/*
 *
 *  ZDKDispatcher.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 08/06/2014.  
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
#import "ZDKDispatcherResponse.h"

/**
 *  API success block.
 *
 *  @since 0.9.3.1
 */
typedef void (^ZDKAPISuccess) (id result);


/**
 *  API error block.
 *
 *  @since 0.9.3.1
 */
typedef void (^ZDKAPIError) (NSError *error);


/**
 *  Convenience method for executing a block on the request queue.
 *
 *  @since 0.9.3.1
 *
 *  @param queue The queue that will execute the block.
 *  @param block Block the block to be executed.
 */
static inline void zdk_on_queue(dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_async(queue, block);
}


/**
 *  Convenience method for executing a block on the UI queue
 *
 *  @since 0.9.3.1
 *  @param block the block to be executed
 */
static inline void zdk_on_main_thread(dispatch_block_t block)
{
    dispatch_async(dispatch_get_main_queue(), block);
}


/**
 *  ZDKAPI Login state.
 *
 *  @since 0.9.3.1
 */
typedef NS_ENUM(NSInteger, ZDKAPILoginState) {

    /**
     *  The SDK has not yet authenticated during this session.
     *
     *  @since 0.9.3.1
     */
    ZDKAPILoginStateNotLoggedIn,

    /**
     *  The SDK is in the process of logging in.
     *
     *  @since 0.9.3.1
     */
    ZDKAPILoginStateLoggingIn,

    /**
     *  The SDK has an oauth token that was valid the last time it was used.
     *
     *  @since 0.9.3.1
     */
    ZDKAPILoginStateLoggedIn
};
