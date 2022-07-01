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

class MainViewController: UITabBarController {

    var homeViewController: HomeViewController? {
        self.homeFeatureViewController.viewControllers.first as? HomeViewController
    }

    private let homeFeatureViewController = FeatureViewController(
        rootViewController: HomeViewController(),
        tabBarItemImageName: "tab-icon-home"
    )

    private let notificationsFeatureViewController = FeatureViewController(
        rootViewController: NotificationsViewController(),
        tabBarItemImageName: "tab-icon-notifications"
    )

    private let channelsFeatureViewController = FeatureViewController(
        rootViewController: ChannelsViewController(),
        tabBarItemImageName: "tab-icon-channels"
    )

    private let directoryFeatureViewController = FeatureViewController(
        rootViewController: DirectoryViewController(),
        tabBarItemImageName: "tab-icon-directory"
    )

    private let everyoneViewController = FeatureViewController(
        rootViewController: DiscoverViewController(),
        tabBarItemImageName: "tab-icon-everyone"
    )

    // custom separator on the top edge of the tab bar
    private var topBorder: UIView?

    convenience init() {

        self.init(nibName: nil, bundle: nil)
        self.delegate = self
        self.view.backgroundColor = .cardBackground
        self.tabBar.configureAppearance()
        self.topBorder = Layout.addSeparator(toTopOf: self.tabBar, color: UIColor.separator.bar)

        let controllers = [
            self.homeFeatureViewController,
            self.everyoneViewController,
            self.notificationsFeatureViewController,
            self.channelsFeatureViewController,
            self.directoryFeatureViewController
        ]
        self.setViewControllers(controllers, animated: false)
    }
    
    func setTopBorder(hidden: Bool, animated: Bool = true) {
        let duration = animated ? 0.3 : 0
        UIView.animate(withDuration: duration) {
            self.topBorder?.alpha = hidden ? 0 : 1
        }
    }

    func isNotificationsTabSelected() -> Bool {
        self.selectedViewController == self.notificationsFeatureViewController
    }

    func triggerUpdateInNotificationsScreen() {
        if let controller = self.notificationsFeatureViewController.children.first as? NotificationsViewController {
            controller.checkForNotificationUpdates(force: true)
        }
    }

    // Simply selects the notifications.  Useful during launch or resume if
    // needing to show notifications.
    func selectNotificationsTab() {
        triggerUpdateInNotificationsScreen()
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
        self.clearNotificationsTabIcon(whenSwitchingTo: viewController)

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

    /// Clears the notifications tab icon (returns it back to the "no new content" state) when necessary.
    private func clearNotificationsTabIcon(whenSwitchingTo controller: UIViewController) {

        // if not on notifications and going to notifications, clear
        // if on notifications and leaving, clear
        let onNotifications = self.selectedViewController == self.notificationsFeatureViewController
        let goingToNotifications = controller == self.notificationsFeatureViewController
        guard (onNotifications && !goingToNotifications) || (!onNotifications && goingToNotifications) else {
            return
        }

        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
