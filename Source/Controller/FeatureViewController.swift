//
//  FeatureViewController.swift
//  FBTT
//
//  Created by Christoph on 3/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics

class FeatureViewController: UINavigationController {

    private lazy var profileButton: AvatarButton = {
        let button = AvatarButton()
        button.addTarget(self, action: #selector(profileButtonTouchUpInside), for: .touchUpInside)
        button.constrainSize(to: 35)
        button.frame = CGRect(x: 0, y: 0, width: 35, height: 35)
        button.round()
        button.transform = CGAffineTransform(translationX: -1, y: -3)
        return button
    }()

    private lazy var profileBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(customView: self.profileButton)
        return item
    }()

    private var cachedTabBarItemImageName: String?
    
    // MARK: Lifecycle

    // Note that this initializer seems to be required for iOS 12 compatibility.
    // We'll eventually require iOS 13 so this won't be an issue, but it is interesting
    // that the Xcode 11 compiler did not complain and this was only discovered
    // by launching and crashing on a 12.x device.
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    init(rootViewController: UIViewController, tabBarItemImageName: String? = nil) {
        super.init(rootViewController: rootViewController)
        self.navigationBar.showBottomSeparator()
        self.setTabBarItem(title: rootViewController.navigationItem.title, image: tabBarItemImageName)
        rootViewController.navigationItem.leftBarButtonItem = self.profileBarButtonItem
    }

    private func setTabBarItem(title: String?, image named: String? = nil) {
        guard let name = named ?? cachedTabBarItemImageName, setTabBarItemImage(name) else {
            return
        }
        self.tabBarItem.accessibilityLabel = title
    }
        
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            setTabBarItem(title: viewControllers.first?.navigationItem.title)
        }
    }

    override func viewWillLayoutSubviews() {
        navigationBar.topItem?.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }

    @discardableResult
    func setTabBarItemImage(_ name: String) -> Bool {
        guard let image = UIImage(named: name) else {
            return false
        }
        guard let selected = UIImage(named: "\(name)-selected") else {
            return false
        }
        cachedTabBarItemImageName = name
        let tabBarItem = UITabBarItem(title: nil, image: image, selectedImage: selected)
        tabBarItem.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
        self.tabBarItem = tabBarItem
        return true
    }

    func setTabBarItemBadge(_ value: Int?) {
        if let value = value {
            tabBarItem?.badgeValue = "\(value)"
        } else {
            tabBarItem?.badgeValue = nil
        }
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.profileButton.setImageForMe()
    }

    // MARK: Actions

    @objc
    func profileButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "menu")
        AppController.shared.showMenuViewController()
    }
}
