//
//  AppDelegate+UIAppearance.swift
//  FBTT
//
//  Created by Christoph on 4/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension AppDelegate {

    /// Configures the appearance for many of the UI elements in the app.  iOS 13
    /// changes how the UIAppearance APIs work, like for UITabBar, but these seem
    /// to work for all versions.  As things change, especially when iOS 13 becomes
    /// the deployment target, this will likely need to be updated similar to the UITabBar
    /// extension.
    func configureAppearance() {

        // default tint across app, affects buttons
        UIWindow.appearance().tintColor = UIColor.tint.default

        // nav bar
        // we have to set the image because setting the backgroundColor
        // ends up with a slightly different color for some reason
        let image = UIImage(named: "back-chevron")
        let appearance = UINavigationBar.appearance()
        appearance.backIndicatorImage = image
        appearance.backIndicatorTransitionMaskImage = image
        appearance.tintColor = UIColor.tint.default
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: UIColor.secondaryText
        ]

        // clear the bottom shadow edge to allow for a custom edge
        appearance.shadowImage = UIColor.clear.image(dimension: 1)

        appearance.isTranslucent = false
        appearance.backgroundColor = .cardBackground
        appearance.barTintColor = .cardBackground

        // refresh control
        UIRefreshControl.appearance().tintColor = .loadingIcon

        // search bar
        UISearchBar.appearance().backgroundColor = .cardBackground
        
        // table footers and headers
        let footerColor = UIColor.secondaryText
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self]).textColor = footerColor
    }
}

extension UITabBar {

    /// Configures this instance of a UIITabBar.  iOS 13 introduced new UIAppearance APIs however
    /// they don't seem to work the same as the proxy APIs previously.  So, configuring the appearance
    /// must be called on a particular UITabBar instance to work correctly, so this extension was created
    /// to be used for all versions.
    func configureAppearance() {
        if #available(iOS 13, *) {
            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.normal.iconColor = .unselectedTab
            itemAppearance.normal.badgeBackgroundColor = .selectedTab
            itemAppearance.selected.iconColor = .selectedTab
            itemAppearance.selected.badgeBackgroundColor = .selectedTab
            
            let appearance = UITabBarAppearance()
            appearance.stackedLayoutAppearance = itemAppearance
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .cardBackground
            appearance.backgroundImage = UIImage()
            appearance.shadowColor = nil
            appearance.shadowImage = UIImage()
            self.standardAppearance = appearance
        } else {
            let appearance = UITabBar.appearance()
            appearance.backgroundColor = .cardBackground
            appearance.backgroundImage = UIImage()
            appearance.shadowImage = UIImage()
            appearance.unselectedItemTintColor = .unselectedTab
        }
    }
}
