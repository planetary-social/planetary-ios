//
//  UIColor+Verse.swift
//  FBTT
//
//  Created by Christoph on 3/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// Colors based on Asset catalog and supporting iOS Dark Mode
// note that Asset catalog colors are optional so some may require
// a non-optional value to be used across the app
extension UIColor {
    
    static let appBackground = UIColor(named: "appBackground", in: Bundle.current, compatibleWith: nil) ?? UIColor.white
    static let mainText = UIColor(named: "mainText", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let secondaryText = UIColor(named: "secondaryText", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let reactionUser = UIColor(named: "reactionUser", in: Bundle.current, compatibleWith: nil)!
    static let primaryAction = UIColor(named: "primaryAction", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let secondaryAction = UIColor(named: "secondaryAction", in: Bundle.current, compatibleWith: nil)!
    static let cardBackground = UIColor(named: "cardBackground", in: Bundle.current, compatibleWith: nil)!
    static let cardBorder = UIColor(named: "cardBorder", in: Bundle.current, compatibleWith: nil)!
    static let splashBackground = UIColor(named: "splashBackgroundColor", in: Bundle.current, compatibleWith: nil) ?? UIColor.white
    static let screenOverlay = UIColor(named: "screenOverlay", in: Bundle.current, compatibleWith: nil) ?? UIColor.black.withAlphaComponent(30)
    static let menuBackgroundColor = UIColor(named: "menuBackgroundColor", in: Bundle.current, compatibleWith: nil) ?? UIColor.white
    static let menuBorderColor = UIColor(named: "menuBorderColor", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let menuSelectedItemBackground = UIColor(named: "menuSelectedItemBackground", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let menuSelectedItemText = UIColor(named: "menuSelectedItemText", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let menuUnselectedItemText = UIColor(named: "menuUnselectedItemText", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let loadingIcon = UIColor(named: "loadingIcon", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let avatarRing = UIColor(named: "avatarRing", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let networkAnimation = UIColor(named: "networkAnimation", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
    static let selectedTab = UIColor(named: "selectedTab", in: Bundle.current, compatibleWith: nil)!
    static let unselectedTab = UIColor(named: "unselectedTab", in: Bundle.current, compatibleWith: nil)!
    static let textInputBorder = UIColor(named: "textInputBorder", in: Bundle.current, compatibleWith: nil)!
    static let textInputBackground = UIColor(named: "textInputBackground", in: Bundle.current, compatibleWith: nil)!
    static let linkColor = UIColor(named: "linkColor", in: Bundle.current, compatibleWith: nil)!

    struct background {
        static let gallery = UIColor(named: "galleryColor", in: Bundle.current, compatibleWith: nil) ?? UIColor(rgb: 0xEFEFEF)
        static let splash = UIColor(named: "splashBackgroundColor", in: Bundle.current, compatibleWith: nil) ?? UIColor.white
    }

    struct border {
        static let text = UIColor(named: "textBorderColor", in: Bundle.current, compatibleWith: nil) ?? UIColor(rgb: 0xEAEAEA)
    }

    struct separator {
        static let bar = UIColor(named: "separator.default", in: Bundle.current, compatibleWith: nil) ?? UIColor(rgb: 0xc3c3c3)
        static let bottom = UIColor(named: "separator.default", in: Bundle.current, compatibleWith: nil) ?? UIColor(rgb: 0xc3c3c3)
        static let menu = UIColor(named: "separator.default", in: Bundle.current, compatibleWith: nil) ?? UIColor(rgb: 0xc3c3c3)
        static let middle = UIColor(named: "separator.default", in: Bundle.current, compatibleWith: nil) ?? UIColor(rgb: 0xc3c3c3)
        static let top = UIColor(named: "separator.default", in: Bundle.current, compatibleWith: nil) ?? UIColor(rgb: 0xc3c3c3)
    }

    struct text {
        static let `default` = UIColor(named: "textColor", in: Bundle.current, compatibleWith: nil) ?? UIColor.black
        static let detail = UIColor(named: "detailTextColor", in: Bundle.current, compatibleWith: nil) ?? UIColor.gray
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
        static let `default` = UIColor(named: "defaultTint", in: Bundle.current, compatibleWith: nil) ?? #colorLiteral(red: 0.3254901961, green: 0.2431372549, blue: 0.4862745098, alpha: 1)
        static let system = #colorLiteral(red: 0, green: 0.4623456597, blue: 1, alpha: 1)
    }
}
