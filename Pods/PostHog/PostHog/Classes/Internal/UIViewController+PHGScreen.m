#import "UIViewController+PHGScreen.h"
#import <objc/runtime.h>
#import "PHGPostHog.h"
#import "PHGUtils.h"


@implementation UIViewController (PHGScreen)

+ (BOOL)isAppExtension {
#if TARGET_OS_IOS || TARGET_OS_TV
    // Documented by <a href="https://goo.gl/RRB2Up">Apple</a>
  BOOL appExtension = [[[NSBundle mainBundle] bundlePath] hasSuffix:@".appex"];
  return appExtension;
#elif TARGET_OS_OSX
    return NO;
#endif
}

+ (void)phg_swizzleViewDidAppear
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(viewDidAppear:);
        SEL swizzledSelector = @selector(phg_viewDidAppear:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod =
            class_addMethod(class,
                            originalSelector,
                            method_getImplementation(swizzledMethod),
                            method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}


+ (UIViewController *)phg_topViewController
{
    // iOS App extensions should not call [UIApplication sharedApplication], even if UIApplication responds to it.
    static Class applicationClass = nil;
    if (![UIViewController isAppExtension]) {
        Class cls = NSClassFromString(@"UIApplication");
        if (cls && [cls respondsToSelector:NSSelectorFromString(@"sharedApplication")]) {
            applicationClass = cls;
        }
    }

    UIWindow *mainWindow = [[[applicationClass sharedApplication] windows] firstObject];
    UIViewController *root = mainWindow.rootViewController;
    return [self phg_topViewController:root];
}

+ (UIViewController *)phg_topViewController:(UIViewController *)rootViewController
{
    UIViewController *presentedViewController = rootViewController.presentedViewController;
    if (presentedViewController != nil) {
        return [self phg_topViewController:presentedViewController];
    }

    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UIViewController *lastViewController = [[(UINavigationController *)rootViewController viewControllers] lastObject];
        return [self phg_topViewController:lastViewController];
    }

    return rootViewController;
}

- (void)phg_viewDidAppear:(BOOL)animated
{
    UIViewController *top = [[self class] phg_topViewController];
    if (!top) {
        PHGLog(@"Could not infer screen.");
        return;
    }

    NSString *name = [top title];
    if (!name || name.length == 0) {
        name = [[[top class] description] stringByReplacingOccurrencesOfString:@"ViewController" withString:@""];
        // Class name could be just "ViewController".
        if (name.length == 0) {
            PHGLog(@"Could not infer screen name.");
            name = @"Unknown";
        }
    }
    [[PHGPostHog sharedPostHog] screen:name properties:nil];

    [self phg_viewDidAppear:animated];
}

@end
