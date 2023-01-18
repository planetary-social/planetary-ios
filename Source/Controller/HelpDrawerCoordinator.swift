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

protocol HelpDrawerHost {
    var helpDrawerType: HelpDrawer { get }
    var horizontalSizeClass: UserInterfaceSizeClass? { get }
    /// The host should dismiss the drawer if present and call completion after the animation finishes
    func dismissDrawer(completion: (() -> Void)?)
}

/// A protocol for view controllers that host a `HelpDrawer`
protocol HelpDrawerViewControllerHost: HelpDrawerHost, UIViewController {
    var helpButton: UIBarButtonItem { get }
    func helpButtonTouchUpInside()
}

extension HelpDrawerViewControllerHost {

    var horizontalSizeClass: UserInterfaceSizeClass? {
        switch traitCollection.horizontalSizeClass {
        case .compact:
            return .compact
        case .regular:
            return .regular
        default:
            return nil
        }
    }

    @MainActor func helpButtonTouchUpInside() {
        HelpDrawerCoordinator.showHelp(for: self)
    }

    func dismissDrawer(completion: (() -> Void)?) {
        self.dismiss(animated: true, completion: completion)
    }
}

class HelpDrawerState: ObservableObject {
    @Published
    var isShowingHomeHelpDrawer = false

    @Published
    var isShowingDiscoverHelpDrawer = false

    @Published
    var isShowingHashtagsHelpDrawer = false

    init(isShowingHome: Bool = false, isShowingDiscover: Bool = false, isShowingHashtags: Bool = false) {
        self.isShowingHomeHelpDrawer = isShowingHome
        self.isShowingDiscoverHelpDrawer = isShowingDiscover
        self.isShowingHashtagsHelpDrawer = isShowingHashtags
    }
}
    
/// A bunc of stateless functions to help with showing help drawers.
enum HelpDrawerCoordinator {
    
    /// Shows the help drawer for the given host view controller.
    @MainActor static func showHelp(for viewController: HelpDrawerViewControllerHost) {
        let helpDrawerType = viewController.helpDrawerType
        if viewController.presentedViewController == nil {
            let controller = HelpDrawerCoordinator.helpController(for: viewController)
            viewController.present(controller, animated: true, completion: nil)
            didShowHelp(for: helpDrawerType)
        }
        
        Analytics.shared.trackDidShowScreen(screenName: helpDrawerType.screenName)
    }

    /// Marks the help drawer as seen and does not show it again at first time
    @MainActor static func didShowHelp(for helpDrawer: HelpDrawer) {
        UserDefaults.standard.set(true, forKey: helpDrawer.hasSeenDrawerKey)
        UserDefaults.standard.synchronize()
    }

    /// Shows the help drawer only if the user has never seen it before.
    @MainActor static func showFirstTimeHelp(for helpDrawer: HelpDrawer, state: HelpDrawerState) {
        if UserDefaults.standard.bool(forKey: helpDrawer.hasSeenDrawerKey) == false {
            switch helpDrawer {
            case .home:
                state.isShowingHomeHelpDrawer = true
            case .discover:
                state.isShowingDiscoverHelpDrawer = true
            case .hashtags:
                state.isShowingHashtagsHelpDrawer = true
            default:
                break
            }
        }
    }

    /// Shows the help drawer only if the user has never seen it before.
    @MainActor static func showFirstTimeHelp(for viewController: HelpDrawerViewControllerHost) {
        let helpDrawerType = viewController.helpDrawerType
        if UserDefaults.standard.bool(forKey: helpDrawerType.hasSeenDrawerKey) == false {
            showHelp(for: viewController)
        }
    }
    
    /// Creates a UIViewController containing the help information. Configures it to be presented as a sheet or
    /// popover depending on size class.
    @MainActor static func helpController(for viewController: HelpDrawerViewControllerHost) -> UIViewController {
        
        let view = helpDrawerView(
            for: viewController,
            dismissAction: { viewController.dismiss(animated: true) }
        )
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
    static func helpBarButton(for host: HelpDrawerViewControllerHost) -> UIBarButtonItem {
        let image = UIImage(systemName: "questionmark.circle")
        return UIBarButtonItem(
            title: Localized.Help.help.text,
            image: image,
            primaryAction: UIAction(handler: { _ in
                host.helpButtonTouchUpInside()
            }),
            menu: nil
        )
    }
    
    /// Builds a closure that will show the given help drawer from the given viewController.
    static func createShowClosure(for drawer: HelpDrawer, from host: HelpDrawerHost) -> () -> Void {
        
        let tabBar = AppController.shared.mainViewController
        
        switch drawer {
        case .home:
            return {
                host.dismissDrawer {
                    let featureVC = tabBar?.homeFeatureViewController
                    tabBar?.selectedViewController = featureVC
                    tabBar?.helpDrawerState.isShowingHomeHelpDrawer = true
                }
            }
        case .discover:
            return {
                host.dismissDrawer {
                    let featureVC = tabBar?.everyoneFeatureViewController
                    tabBar?.selectedViewController = featureVC
                    tabBar?.helpDrawerState.isShowingDiscoverHelpDrawer = true
                }
            }
        case .notifications:
            return {
                host.dismissDrawer {
                    let featureVC = tabBar?.notificationsFeatureViewController
                    let helpHost = featureVC?.viewControllers.first as? NotificationsViewController
                    tabBar?.selectedViewController = featureVC
                    // Yield so we don't end up presenting on a view that hasn't loaded yet.
                    Task { await helpHost?.helpButtonTouchUpInside() }
                }
            }
        case .hashtags:
            return {
                host.dismissDrawer {
                    let featureVC = tabBar?.channelsFeatureViewController
                    tabBar?.selectedViewController = featureVC
                    tabBar?.helpDrawerState.isShowingHashtagsHelpDrawer = true
                }
            }
        case .network:
            return {
                host.dismissDrawer {
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
    /// Builds the SwiftUI help drawer view for the given view controller type.
    @MainActor static func helpDrawerView(
        for host: HelpDrawerHost,
        dismissAction: @escaping () -> Void
    ) -> HelpDrawerView? {
        let inDrawer = host.horizontalSizeClass == .compact
        // This function is a little kludgy but I'm not going to spend time refactoring it now. It would be
        // better to build a configuration object and pass that to the HelpDrawerView initializer rather than having
        // so many parameters.
        switch host.helpDrawerType {
        case .home:
            return HelpDrawerView(
                tabName: Localized.home.text,
                tabImageName: "tab-icon-home",
                heroImageName: nil,
                helpTitle: Localized.Help.Home.title.text,
                bodyText: Localized.Help.Home.body.text,
                highlightedWord: Localized.Help.Home.highlightedWord.text,
                highlight: .diagonalAccent,
                link: MainTab.discover.url,
                inDrawer: inDrawer,
                tipIndex: 1,
                nextTipAction: createShowClosure(for: .discover, from: host),
                previousTipAction: nil,
                dismissAction: dismissAction
            )
        case .discover:
            return HelpDrawerView(
                tabName: Localized.explore.text,
                tabImageName: "tab-icon-everyone",
                heroImageName: "help-hero-discover",
                helpTitle: Localized.Help.Discover.title.text,
                bodyText: Localized.Help.Discover.body.text,
                highlightedWord: Localized.Help.Discover.highlightedWord.text,
                highlight: .diagonalAccent,
                link: MainTab.home.url,
                inDrawer: inDrawer,
                tipIndex: 2,
                nextTipAction: createShowClosure(for: .notifications, from: host),
                previousTipAction: createShowClosure(for: .home, from: host),
                dismissAction: dismissAction
            )
        case .notifications:
            return HelpDrawerView(
                tabName: Localized.notifications.text,
                tabImageName: "tab-icon-notifications",
                heroImageName: "help-hero-notifications",
                helpTitle: Localized.Help.Notifications.title.text,
                bodyText: Localized.Help.Notifications.body.text,
                highlightedWord: nil,
                highlight: .diagonalAccent,
                link: nil,
                inDrawer: inDrawer,
                tipIndex: 3,
                nextTipAction: createShowClosure(for: .hashtags, from: host),
                previousTipAction: createShowClosure(for: .discover, from: host),
                dismissAction: dismissAction
            )
        case .hashtags:
            return HelpDrawerView(
                tabName: Localized.channels.text,
                tabImageName: "tab-icon-channels",
                heroImageName: "help-hero-hashtags",
                helpTitle: Localized.Help.Hashtags.title.text,
                bodyText: Localized.Help.Hashtags.body.text,
                highlightedWord: Localized.Help.Hashtags.highlightedWord.text,
                highlight: .diagonalAccent,
                link: MainTab.network.url,
                inDrawer: inDrawer,
                tipIndex: 4,
                nextTipAction: createShowClosure(for: .network, from: host),
                previousTipAction: createShowClosure(for: .notifications, from: host),
                dismissAction: dismissAction
            )
        case .network:
            return HelpDrawerView(
                tabName: Localized.yourNetwork.text,
                tabImageName: "tab-icon-directory",
                heroImageName: "help-hero-network",
                helpTitle: Localized.Help.YourNetwork.title.text,
                bodyText: Localized.Help.YourNetwork.body.text,
                highlightedWord: Localized.Help.YourNetwork.highlightedWord.text,
                highlight: .solidBlack,
                link: nil,
                inDrawer: inDrawer,
                tipIndex: 5,
                nextTipAction: nil,
                previousTipAction: createShowClosure(for: .hashtags, from: host),
                dismissAction: dismissAction
            )
        }
    }
    // swiftlint:enable function_body_length
}
