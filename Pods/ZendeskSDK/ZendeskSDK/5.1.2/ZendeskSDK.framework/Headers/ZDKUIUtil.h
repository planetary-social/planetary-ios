/*
 *
 *  ZDKUIUtil.h
 *  ZendeskSDK
 *
 *  Created by Zendesk on 15/10/2014.  
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

@interface ZDKUIUtil : NSObject


/**
 *  Gets the UI_APPEARANCE_SELECTOR value for a class.
 *
 *  @param viewClass    The appearance value will come from this class.
 *  @param selector The appearance selector
 *
 *  @return An appearance value or nil if none have been set.
 */
+ (id)appearanceValueForClass:(Class)viewClass selector:(SEL)selector;


/**
 *  Get the UI_APPEARANCE_SELECTOR value for a class when contained in a given class
 *
 *  @param viewClass      The appearance value will come from this class.
 *  @param containerClass The containing class.
 *  @param selector       The appearance selector
 *
 *  @return An appearance value or nil if none have been set.
 *
 *  @since 1.6.0.1
 */
+ (id)appearanceValueForClass:(Class)viewClass whenContainedIn:(Class <UIAppearanceContainer>)containerClass selector:(SEL)selector;


/**
 *  Gets the UI_APPEARANCE_SELECTOR value for a view.
 *
 *  @param view     The appearance value will come from this view.
 *  @param selector The appearance selector.
 *
 *  @return The appearance value or nil if none has been set.
 */
+ (id)appearanceValueForView:(UIView *)view selector:(SEL)selector;


/**
 *  Checks to see if the majorVersionNumber is less than the current device version
 *
 *  @param majorVersionNumber is a single integer, e.g.: 7
 *
 *  @return YES if the current device number is less than majorVersionNumber.
 */
+ (BOOL) isOlderVersion:(NSString *) majorVersionNumber;


/**
 * isNewVersion checks to see if the majorVersionNumber is greater than the current device version
 * @param majorVersionNumber is a single integer, e.g.: 7
 */
+ (BOOL) isNewerVersion:(NSString *) majorVersionNumber;


/**
 * isSameVersion checks to see if the majorVersionNumber is the same as the current device version
 * @param majorVersionNumber is a single integer, e.g.: 7
 */
+ (BOOL) isSameVersion:(NSNumber *) majorVersionNumber;


/**
 * The height of a separator for retina and none retina screens.
 *
 * @return Height of separator.
 */
+ (CGFloat) separatorHeightForScreenScale;


/**
 * Convenience method for creating UIButton.
 *
 * @param frame is the initial frame.
 * @param title is the title string.
 * @return A new button.
 */
+ (UIButton*) buildButtonWithFrame:(CGRect)frame andTitle:(NSString*)title;


/**
 *  Returns current interface orientation. If orientation is unknown presume portrait
 *
 *  @return Current interface orientation
 */
+ (UIInterfaceOrientation) currentInterfaceOrientation;


/**
 *  <#Description#>
 *
 *  @param size  <#size description#>
 *  @param width <#width description#>
 *
 *  @return <#return value description#>
 */
+ (CGFloat) scaledHeightForSize:(CGSize)size constrainedByWidth:(CGFloat)width;


/**
 *  <#Description#>
 *
 *  @return <#return value description#>
 */
+ (BOOL) isPad;


/**
 *  <#Description#>
 *
 *  @return <#return value description#>
 */
+ (BOOL) isLandscape;


/*
 *  Physically transform an image to match its imageRotation property.
 *
 *  @param image Image to rotate.
 *
 *  @return Correctly rotated image.
 */
+ (UIImage *)fixOrientationOfImage:(UIImage*)image;


/**
 *  Checks if the host app is a landscape only app and will enable or disable the attachments 
 *  button accordingly.
 *
 *  @param viewController ViewController to check to enable attachments
 *
 *
 *  @return Returns YES if attchments should be enabled. This is a combination of server config and if the app
 *          supports portrait orientation, as UIImagePicker will crash if it cannot rotate into portrait
 *
 *  @since 1.5.4.1
 */
+ (BOOL) shouldEnableAttachments:(UIViewController *)viewController;



@end

CG_INLINE CGRect
CGRectMakeCenteredInScreen(CGFloat width, CGFloat height)
{
    CGRect screen = [UIScreen mainScreen].bounds;

    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;

    CGRect rect;

    if (orientation == UIInterfaceOrientationLandscapeLeft ||
        orientation == UIInterfaceOrientationLandscapeRight) {
        if([ZDKUIUtil isOlderVersion:@"8.0"])
        {
            rect = CGRectMake(CGRectGetMidY(screen) - (width * 0.5f),
                              CGRectGetMidX(screen) - (height * 0.5f), width, height);
        }else{
            rect = CGRectMake(CGRectGetMidX(screen) - (width * 0.5f),
                              CGRectGetMidY(screen) - (height * 0.5f), width, height);
        }

    } else {
        rect = CGRectMake(CGRectGetMidX(screen) - (width * 0.5f),
                          CGRectGetMidY(screen) - (height * 0.5f), width, height);
    }
    return rect;
}


CG_INLINE CGRect
CGMakeCenteredRectInRect(CGFloat width, CGFloat height, CGRect rect)
{
    return CGRectMake(CGRectGetMidX(rect) - (width * 0.5f),
                      CGRectGetMidY(rect) - (height * 0.5f), width, height);
}


CG_INLINE CGRect
CGMakeCenteredRectOnXInRect(CGFloat width, CGFloat height, CGFloat y, CGRect frame)
{
    CGRect rect;
    rect = CGRectMake(CGRectGetMidX(frame) - (width * 0.5f), y, width, height);
    return rect;
}


CG_INLINE CGRect
CGCenterRectInRect(CGRect rect, CGRect inRect)
{
    return CGRectMake((CGRectGetHeight(inRect) - CGRectGetMinX(rect)) * 0.5f,
                      (CGRectGetHeight(inRect) - CGRectGetHeight(rect)) * 0.5f,
                      CGRectGetWidth(rect),
                      CGRectGetHeight(rect));
}


/**
 * Helper for device orientation.
 */
CG_INLINE BOOL
ZDKUIIsLandscape()
{
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    return UIInterfaceOrientationIsLandscape(orientation);
}


/**
 * Returns the full screen frame with no attempt to account for the status bar.
 */
CG_INLINE CGRect
ZDKUIScreenFrame()
{
    CGSize screenSize = [UIScreen mainScreen].bounds.size;

    CGFloat width = screenSize.width;
    CGFloat height = screenSize.height;

    if (ZDKUIIsLandscape() && width < height) {

        width = height;
        height = screenSize.width;
    }

    return CGRectMake(0, 0, width, height);
}


/**
 * Get the origin of the supplied view in the window.
 */
CG_INLINE CGPoint
ZDKUIOriginInWindow(UIView *view)
{
    UIView *superView = view;
    do {
        superView = superView.superview;
    } while (superView.superview);

    CGPoint point = [view convertPoint:view.bounds.origin toView:superView];
    return point;
}

