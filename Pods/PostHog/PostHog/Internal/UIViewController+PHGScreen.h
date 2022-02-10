#include <TargetConditionals.h>

#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif

@interface UIViewController (PHGScreen)

+ (BOOL)isAppExtension;

+ (void)phg_swizzleViewDidAppear;
+ (UIViewController *)phg_topViewController;

@end
