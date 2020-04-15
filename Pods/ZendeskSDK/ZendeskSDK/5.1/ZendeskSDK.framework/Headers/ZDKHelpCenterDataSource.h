/*
 *
 *  ZDKHelpCenterCategoryDataSource.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 10/09/2014.  
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
#import <UIKit/UIKit.h>

@class ZDKHelpCenterProvider;


/**
 * A block for configuring cells. This is invoked in cell for row at index path.
 */
typedef void (^ZDKHelpCenterCellConfigureBlock)(id cell, id item);


/**
 * The support view that displays help center content.
 */
@interface ZDKHelpCenterDataSource : NSObject <UITableViewDataSource> {
    BOOL _hasItems;
    NSArray *_items;
    ZDKHelpCenterProvider *_provider;
}


/**
 * Read only property, indicating if the DataSource has any items
 */
@property (nonatomic, assign, readonly) BOOL hasItems;


/**
 * Read-only array of items associated with the data source.
 */
@property (nonatomic, copy, readonly) NSArray *items;


/**
 * Help Center provider.
 */
@property (nonatomic, strong, readonly) ZDKHelpCenterProvider *provider;


/**
 * Reloads the data source. 
 */
- (void) reloadData;

/**
 * Retrieves an item for the given index path. 
 *
 * @param indexPath The index path for the item to be retrieved.
 * @return An item, depending on the data source this could be a category, section or article.
 */
- (id)itemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns cell identifier for the data source. Default ZDKHelpCenterTableViewCell. Override if using a different cell type.
 */
+ (NSString *) cellIdentifierForDataSource;



@end


