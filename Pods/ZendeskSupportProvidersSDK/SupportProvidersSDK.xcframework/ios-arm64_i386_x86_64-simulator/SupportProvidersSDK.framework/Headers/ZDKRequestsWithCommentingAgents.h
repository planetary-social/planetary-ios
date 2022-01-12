//
//  ZDKRequestsWithCommentingAgents.h
//  SupportProvidersSDK
//
//  Created by Ronan Mchugh on 15/12/2017.
//  Copyright © 2017 Zendesk. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZDKSupportUser, ZDKRequest;

@interface ZDKRequestsWithCommentingAgents : NSObject

@property (nonatomic, strong) NSArray<ZDKRequest *> *requests;
@property (nonatomic, strong) NSArray<ZDKSupportUser *> *commentingAgents;


- (instancetype)initWithRequests:(NSArray <ZDKRequest*>*)requests andCommentingAgents:(NSArray <ZDKSupportUser*>*)commentingAgents;

@end
