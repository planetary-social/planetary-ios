//
//  HelpDrawerCoordinator.swift.
//  Planetary
//
//  Created by Matthew Lorentz on 7/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit
import SwiftUI
import Analytics
import Logger

/// A model for help UI that is presented in a sheet or popover.
enum HelpDrawer {
    case home, discover, notifications, hashtags, network
    
    init?(viewController: HelpDrawerHost) {
        if viewController is HomeViewController {
            self = .home
        } else if viewController is DiscoverViewController {
            self = .discover
        } else if viewController is NotificationsViewController {
            self = .notifications
        } else if viewController is ChannelsViewController {
            self = .hashtags
        } else if viewController is DirectoryViewController {
            self = .network
        } else {
            return nil
        }
    }
    
    /// A key used to persist whether or not users have seen a given drawer.
    var hasSeenDrawerKey: String {
        switch self {
        case .home:
            return "hasSeenHomeHelpDrawer"
        case .discover:
            return "hasSeenDiscoverHelpDrawer"
        case .notifications:
            return "hasSeenNotificationsHelpDrawer"
        case .hashtags:
            return "hasSeenHashtagsHelpDrawer"
        case .network:
            return "hasSeenYourNetworkHelpDrawer"
        }
    }
    
    /// A name for the drawer used for analytics.
    var screenName: String {
        switch self {
        case .home:
            return "Home Help Drawer"
        case .discover:
            return "Discover Help Drawer"
        case .notifications:
            return "Notifications Help Drawer"
        case .hashtags:
            return "Hashtags Help Drawer"
        case .network:
            return "Your Network Help Drawer"
        }
    }
}

/// A protocol for view controllers that host a `HelpDrawer`
protocol HelpDrawerHost: UIViewController {
    var helpButton: UIBarButtonItem { get }
    func helpButtonTouchUpInside()
}

extension HelpDrawerHost {
    
    @MainActor func helpButtonTouchUpInside() {
        HelpDrawerCoordinator.showHelp(for: self)
    }
}
    
/// A bunc of stateless functions to help with showing help drawers.
enum HelpDrawerCoordinator {
    
    /// Shows the help drawer for the given host view controller.
    @MainActor static func showHelp(for viewController: HelpDrawerHost) {
        guard let helpDrawerType = HelpDrawer(viewController: viewController) else {
            Log.error("Tried to present a help drawer for an unkown view controller.")
            return
        }
        
        if viewController.presentedViewController == nil {
            let controller = HelpDrawerCoordinator.helpController(for: viewController)
            viewController.present(controller, animated: true, completion: nil)
            UserDefaults.standard.set(true, forKey: helpDrawerType.hasSeenDrawerKey)
            UserDefaults.standard.synchronize()
        }
        
        Analytics.shared.trackDidShowScreen(screenName: helpDrawerType.screenName)
    }
        
    /// Shows the help drawer only if the user has never seen it before.
    @MainActor static func showFirstTimeHelp(for viewController: HelpDrawerHost) {
        guard let helpDrawerType = HelpDrawer(viewController: viewController) else {
            Log.error("Tried to present a help drawer for an unkown view controller.")
            return
        }
        
        if UserDefaults.standard.bool(forKey: helpDrawerType.hasSeenDrawerKey) == false {
            showHelp(for: viewController)
        }
    }
    
    /// Creates a UIViewController containing the help information. Configures it to be presented as a sheet or
    /// popover depending on size class.
    @MainActor static func helpController(for viewController: HelpDrawerHost) -> UIViewController {
        
        let view = helpDrawerView(for: viewController, dismissAction: { viewController.dismiss(animated: true) })
        let controller = UIHostingController(rootView: view)
        
        controller.modalPresentationStyle = .popover
        controller.modalTransitionStyle = .coverVertical
        if let hostPopover = controller.popoverPresentationController {
            hostPopover.barButtonItem = viewController.helpButton
            let sheet = hostPopover.adaptiveSheetPresentationController
            sheet.detents = [.medium()]
        }
        
        return controller
    }
    
    /// Creates a help button for the navigation bar that presents the help drawer for the given host view controller.
    static func helpBarButton(for host: HelpDrawerHost) -> UIBarButtonItem {
        let image = UIImage(systemName: "questionmark.circle")
        return UIBarButtonItem(
            title: Text.Help.help.text,
            image: image,
            primaryAction: UIAction(handler: { _ in
                host.helpButtonTouchUpInside()
            }),
            menu: nil
        )
    }
    
    /// Builds a closure that will show the given help drawer from the given viewController.
    static func createShowClosure(for drawer: HelpDrawer, from viewController: UIViewController) -> () -> Void {
        
        let tabBar = AppController.shared.mainViewController
        
        switch drawer {
        case .home:
            return {
                viewController.dismiss(animated: true) {
                    let featureVC = tabBar?.homeFeatureViewController
                    let helpHost = featureVC?.viewControllers.first as? HomeViewController
                    tabBar?.selectedViewController = featureVC
                    // Yield so we don't end up presenting on a view that hasn't loaded yet.
                    Task { await helpHost?.helpButtonTouchUpInside() }
                }
            }
            
        case .discover:
            return {
                viewController.dismiss(animated: true) {
                    let featureVC = tabBar?.everyoneViewController
                    let helpHost = featureVC?.viewControllers.first as? DiscoverViewController
                    tabBar?.selectedViewController = featureVC
                    // Yield so we don't end up presenting on a view that hasn't loaded yet.
                    Task { await helpHost?.helpButtonTouchUpInside() }
                }
            }
        case .notifications:
            return {
                viewController.dismiss(animated: true) {
                    let featureVC = tabBar?.notificationsFeatureViewController
                    let helpHost = featureVC?.viewControllers.first as? NotificationsViewController
                    tabBar?.selectedViewController = featureVC
                    // Yield so we don't end up presenting on a view that hasn't loaded yet.
                    Task { await helpHost?.helpButtonTouchUpInside() }
                }
            }
        case .hashtags:
            return {
                viewController.dismiss(animated: true) {
                    let featureVC = tabBar?.channelsFeatureViewController
                    let helpHost = featureVC?.viewControllers.first as? ChannelsViewController
                    tabBar?.selectedViewController = featureVC
                    // Yield so we don't end up presenting on a view that hasn't loaded yet.
                    Task { await helpHost?.helpButtonTouchUpInside() }
                }
            }
        case .network:
            return {
                viewController.dismiss(animated: true) {
                    let featureVC = tabBar?.directoryFeatureViewController
                    let helpHost = featureVC?.viewControllers.first as? DirectoryViewController
                    tabBar?.selectedViewController = featureVC
                    // Yield so we don't end up presenting on a view that hasn't loaded yet.
                    Task { await helpHost?.helpButtonTouchUpInside() }
                }
            }
        }
    }
    
    // swiftlint:disable function_body_length
    /// Builds the SwiftUI help drawer view for the given view controller.
    @MainActor private static func helpDrawerView(
        for viewController: UIViewController,
        dismissAction: @escaping () -> Void
    ) -> HelpDrawerView? {
        
        let inDrawer = viewController.traitCollection.horizontalSizeClass == .compact
        
        // This function is a little kludgy but I'm not going to spend time refactoring it now. It would be
        // better to build a configuration object and pass that to the HelpDrawerView initializer rather than having
        // so many parameters.
        if viewController is HomeViewController {
            return HelpDrawerView(
                tabName: Text.home.text,
                tabImageName: "tab-icon-home",
                heroImageName: nil,
                helpTitle: Text.Help.Home.title.text,
                bodyText: Text.Help.Home.body.text,
                highlightedWord: Text.Help.Home.highlightedWord.text,
                highlight: .diagonalAccent,
                link: MainTab.discover.url,
                inDrawer: inDrawer,
                tipIndex: 1,
                nextTipAction: createShowClosure(for: .discover, from: viewController),
                previousTipAction: nil,
                dismissAction: dismissAction
            )
        } else if viewController is DiscoverViewController {
            return HelpDrawerView(
                tabName: Text.explore.text,
                tabImageName: "tab-icon-everyone",
                heroImageName: "help-hero-discover",
                helpTitle: Text.Help.Discover.title.text,
                bodyText: Text.Help.Discover.body.text,
                highlightedWord: Text.Help.Discover.highlightedWord.text,
                highlight: .diagonalAccent,
                link: MainTab.home.url,
                inDrawer: inDrawer,
                tipIndex: 2,
                nextTipAction: createShowClosure(for: .notifications, from: viewController),
                previousTipAction: createShowClosure(for: .home, from: viewController),
                dismissAction: dismissAction
            )
        } else if viewController is NotificationsViewController {
            return HelpDrawerView(
                tabName: Text.notifications.text,
                tabImageName: "tab-icon-notifications",
                heroImageName: "help-hero-notifications",
                helpTitle: Text.Help.Notifications.title.text,
                bodyText: Text.Help.Notifications.body.text,
                highlightedWord: nil,
                highlight: .diagonalAccent,
                link: nil,
                inDrawer: inDrawer,
                tipIndex: 3,
                nextTipAction: createShowClosure(for: .hashtags, from: viewController),
                previousTipAction: createShowClosure(for: .discover, from: viewController),
                dismissAction: dismissAction
            )
        } else if viewController is ChannelsViewController {
            return HelpDrawerView(
                tabName: Text.channels.text,
                tabImageName: "tab-icon-channels",
                heroImageName: "help-hero-hashtags",
                helpTitle: Text.Help.Hashtags.title.text,
                bodyText: Text.Help.Hashtags.body.text,
                highlightedWord: Text.Help.Hashtags.highlightedWord.text,
                highlight: .diagonalAccent,
                link: MainTab.network.url,
                inDrawer: inDrawer,
                tipIndex: 4,
                nextTipAction: createShowClosure(for: .network, from: viewController),
                previousTipAction: createShowClosure(for: .notifications, from: viewController),
                dismissAction: dismissAction
            )
        } else if viewController is DirectoryViewController {
            return HelpDrawerView(
                tabName: Text.yourNetwork.text,
                tabImageName: "tab-icon-directory",
                heroImageName: "help-hero-network",
                helpTitle: Text.Help.YourNetwork.title.text,
                bodyText: Text.Help.YourNetwork.body.text,
                highlightedWord: Text.Help.YourNetwork.highlightedWord.text,
                highlight: .solidBlack,
                link: nil,
                inDrawer: inDrawer,
                tipIndex: 5,
                nextTipAction: nil,
                previousTipAction: createShowClosure(for: .hashtags, from: viewController),
                dismissAction: dismissAction
            )
        } else {
            return nil
        }
    }
    // swiftlint:enable function_body_length
}
