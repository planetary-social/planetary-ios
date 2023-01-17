//
//  MainViewController.swift
//  FBTT
//
//  Created by Christoph on 2/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics
import Logger
import SwiftUI

enum MainTab {
    case home, discover, notifications, hashtags, network
    
    init?(urlPath: String) {
        switch urlPath {
        case "/home":
            self = .home
        case "/discover":
            self = .discover
        case "/notifications":
            self = .notifications
        case "/hashtags":
            self = .hashtags
        case "/network":
            self = .network
        default:
            return nil
        }
    }
    
    var urlPath: String {
        switch self {
        case .home:
            return "home"
        case .discover:
            return "discover"
        case .notifications:
            return "notifications"
        case .hashtags:
            return "hashtags"
        case .network:
            return "network"
        }
    }
    
    var url: URL? {
        URL(string: "\(URL.planetaryScheme)://planetary/\(urlPath)")
    }
    
    static func createShowClosure(for tab: MainTab) -> () -> Void {
        
        let tabBar = AppController.shared.mainViewController
        
        switch tab {
        case .home:
            return {
                tabBar?.selectedViewController?.dismiss(animated: true)
                let featureVC = tabBar?.homeFeatureViewController
                tabBar?.selectedViewController = featureVC
            }
        case .discover:
            return {
                tabBar?.selectedViewController?.dismiss(animated: true)
                let featureVC = tabBar?.everyoneViewController
                tabBar?.selectedViewController = featureVC
            }
        case .notifications:
            return {
                tabBar?.selectedViewController?.dismiss(animated: true)
                let featureVC = tabBar?.notificationsFeatureViewController
                tabBar?.selectedViewController = featureVC
            }
        case .hashtags:
            return {
                tabBar?.selectedViewController?.dismiss(animated: true)
                let featureVC = tabBar?.channelsFeatureViewController
                tabBar?.selectedViewController = featureVC
            }
        case .network:
            return {
                tabBar?.selectedViewController?.dismiss(animated: true)
                let featureVC = tabBar?.directoryFeatureViewController
                tabBar?.selectedViewController = featureVC
            }
        }
    }
}

class MainViewController: UITabBarController {

    let helpDrawerState = HelpDrawerState()

    let homeFeatureViewController: FeatureViewController

    let notificationsFeatureViewController = FeatureViewController(
        rootViewController: NotificationsViewController(),
        tabBarItemImageName: "tab-icon-notifications"
    )

    let channelsFeatureViewController: FeatureViewController

    let directoryFeatureViewController = FeatureViewController(
        rootViewController: DirectoryViewController(),
        tabBarItemImageName: "tab-icon-directory"
    )

    let everyoneViewController: FeatureViewController

    // custom separator on the top edge of the tab bar
    private var topBorder: UIView?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        homeFeatureViewController = FeatureViewController(
            rootViewController: UIHostingController(
                rootView: HomeView(helpDrawerState: helpDrawerState, bot: Bots.current).injectAppEnvironment()
            ),
            tabBarItemImageName: "tab-icon-home"
        )
        everyoneViewController = FeatureViewController(
            rootViewController: UIHostingController(
                rootView: DiscoverView(helpDrawerState: helpDrawerState, bot: Bots.current).injectAppEnvironment()
            ),
            tabBarItemImageName: "tab-icon-everyone"
        )
        channelsFeatureViewController = FeatureViewController(
            rootViewController: UIHostingController(
                rootView: HashtagListView(helpDrawerState: helpDrawerState).injectAppEnvironment()
            ),
            tabBarItemImageName: "tab-icon-channels"
        )
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    convenience init() {
        self.init(nibName: nil, bundle: nil)
        self.delegate = self
        self.view.backgroundColor = .cardBackground
        self.tabBar.configureAppearance()
        self.topBorder = Layout.addSeparator(toTopOf: self.tabBar, color: UIColor.separator.bar)
        setNotificationsTabBarIcon()
        let controllers = [
            self.homeFeatureViewController,
            self.everyoneViewController,
            self.notificationsFeatureViewController,
            self.channelsFeatureViewController,
            self.directoryFeatureViewController
        ]
        self.setViewControllers(controllers, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Updates the icon of the notifications tab bar item to match the application badge number
    func setNotificationsTabBarIcon() {
        DispatchQueue.main.async { [weak self] in
            let numberOfNotifications = UIApplication.shared.applicationIconBadgeNumber
            if numberOfNotifications > 0 {
                self?.notificationsFeatureViewController.setTabBarItemImage("tab-icon-has-notifications")
                self?.notificationsFeatureViewController.setTabBarItemBadge(numberOfNotifications)
            } else {
                self?.notificationsFeatureViewController.setTabBarItemImage("tab-icon-notifications")
                self?.notificationsFeatureViewController.setTabBarItemBadge(nil)
            }
        }
    }
    
    func setTopBorder(hidden: Bool, animated: Bool = true) {
        let duration = animated ? 0.3 : 0
        UIView.animate(withDuration: duration) {
            self.topBorder?.alpha = hidden ? 0 : 1
        }
    }

    // Simply selects the notifications.  Useful during launch or resume if
    // needing to show notifications.
    func selectNotificationsTab() {
        self.selectedViewController = self.notificationsFeatureViewController
    }
    
    func selectDirectoryTab() {
        self.selectedViewController = self.directoryFeatureViewController
    }
}

protocol TopScrollable {
    func scrollToTop()
}

// MARK: - UITabBarControllerDelegate

extension MainViewController: UITabBarControllerDelegate {

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        let indexOfTargetViewController = viewControllers?.firstIndex(where: { $0 == viewController })
        guard let targetIndex = indexOfTargetViewController, self.selectedIndex == targetIndex else {
            return true
        }
        
        switch targetIndex {
        case 0:
            Analytics.shared.trackDidTapTab(tabName: "home")
        case 1:
            Analytics.shared.trackDidTapTab(tabName: "everyone")
        case 2:
            Analytics.shared.trackDidTapTab(tabName: "notifications")
        case 3:
            Analytics.shared.trackDidTapTab(tabName: "channels")
        case 4:
            Analytics.shared.trackDidTapTab(tabName: "directory")
        default:
            break
        }
        
        if let featureVC = viewController as? FeatureViewController,
            featureVC.viewControllers.count == 1,
            let rootVC = featureVC.viewControllers.first as? TopScrollable {
            rootVC.scrollToTop()
        }

        return true
    }
}
