//
//  UIColor+Verse.swift
//  FBTT
//
//  Created by Christoph on 3/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// swiftlint:disable line_length force_unwrapping

// Colors based on Asset catalog and supporting iOS Dark Mode
// note that Asset catalog colors are optional so some may require
// a non-optional value to be used across the app
extension UIColor {
    
    static let appBackground = UIColor(named: "appBackground") ?? UIColor.white
    static let mainText = UIColor(named: "mainText") ?? UIColor.black
    static let secondaryText = UIColor(named: "secondaryText") ?? UIColor.black
    static let reactionUser = UIColor(named: "reactionUser")!
    static let primaryAction = UIColor(named: "primaryAction") ?? UIColor.black
    static let secondaryAction = UIColor(named: "secondaryAction")!
    static let cardBackground = UIColor(named: "cardBackground")!
    static let cardBorder = UIColor(named: "cardBorder")!
    static let splashBackground = UIColor(named: "splashBackgroundColor") ?? UIColor.white
    static let screenOverlay = UIColor(named: "screenOverlay") ?? UIColor.black.withAlphaComponent(30)
    static let menuBackgroundColor = UIColor(named: "menuBackgroundColor") ?? UIColor.white
    static let menuBorderColor = UIColor(named: "menuBorderColor") ?? UIColor.black
    static let menuSelectedItemBackground = UIColor(named: "menuSelectedItemBackground") ?? UIColor.black
    static let menuSelectedItemText = UIColor(named: "menuSelectedItemText") ?? UIColor.black
    static let menuUnselectedItemText = UIColor(named: "menuUnselectedItemText") ?? UIColor.black
    static let loadingIcon = UIColor(named: "loadingIcon") ?? UIColor.black
    static let avatarRing = UIColor(named: "avatarRing") ?? UIColor.black
    static let networkAnimation = UIColor(named: "networkAnimation") ?? UIColor.black
    static let selectedTab = UIColor(named: "selectedTab")!
    static let unselectedTab = UIColor(named: "unselectedTab")!
    static let textInputBorder = UIColor(named: "textInputBorder")!
    static let textInputBackground = UIColor(named: "textInputBackground")!

    struct background {
        static let gallery = UIColor(named: "galleryColor") ?? UIColor(rgb: 0xEFEFEF)
        static let splash = UIColor(named: "splashBackgroundColor") ?? UIColor.white
    }

    struct border {
        static let text = UIColor(named: "textBorderColor") ?? UIColor(rgb: 0xEAEAEA)
    }

    struct separator {
        static let bar = UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
        static let bottom = UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
        static let menu = UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
        static let middle = UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
        static let top = UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
    }

    struct text {
        static let `default` =              UIColor(named: "textColor") ?? UIColor.black
        static let detail = UIColor(named: "detailTextColor") ?? UIColor.gray
        static let notificationContent = UIColor(rgb: 0x868686)
        static let notificationTimestamp = UIColor(rgb: 0xADADAD)

        static var reply: UIColor {
            text.default
        }

        static var placeholder: UIColor {
            text.detail
        }
    }

    struct tint {
        static let `default` = UIColor(named: "defaultTint") ?? #colorLiteral(red: 0.3254901961, green: 0.2431372549, blue: 0.4862745098, alpha: 1)
        static let system = #colorLiteral(red: 0, green: 0.4623456597, blue: 1, alpha: 1)
    }
}
