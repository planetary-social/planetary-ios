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

    struct background {
        static let `default` =  UIColor(named: "backgroundColor") ?? UIColor.white
        static let gallery =    UIColor(named: "galleryColor") ?? UIColor(rgb: 0xEFEFEF)
        static let menu =       UIColor(named: "menuBackgroundColor") ?? UIColor(rgb: 0x252525)
        static let reply =      UIColor(named: "replyBackground") ?? UIColor(rgb: 0xEFEFEF)
        static let table =      UIColor(named: "tableBackgroundColor") ?? UIColor(rgb: 0xF4F4F4)
    }
    
    struct tabBar {
        static let background = UIColor(named: "tabBarBackgroundColor") ?? UIColor.white
        static let normalItem = UIColor(named: "tabItemNormalColor") ?? UIColor.black
    }
    
    struct navigationBar {
        static let background = UIColor(named: "tabBarBackgroundColor") ?? UIColor.white
    }
    
    struct searchBar {
        static let background = UIColor(named: "tabBarBackgroundColor") ?? UIColor.white
    }
    
    struct tableView {
        static let cellBackground = UIColor(named: "postBackgroundColor") ?? UIColor.white
    }
    
    struct post {
        static let background = UIColor(named: "postBackgroundColor") ?? UIColor.white
        static let border = UIColor(named: "postBorderColor") ?? UIColor.black
        static let headerText = UIColor(named: "postHeaderTextColor") ?? UIColor.white
    }

    struct border {
        static let text = UIColor(named: "textBorderColor") ?? UIColor(rgb: 0xEAEAEA)
    }

    struct highlight {
        static let menu = UIColor(named: "menuHighlightColor") ?? UIColor(rgb: 0xF4F4F4)
    }

    struct separator {
        static let bar =    UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
        static let bottom = UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
        static let menu =   UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
        static let middle = UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
        static let top =    UIColor(named: "separator.default") ?? UIColor(rgb: 0xc3c3c3)
    }

    struct text {
        static let `default` =              UIColor(named: "textColor") ?? UIColor.black
        static let detail =                 UIColor(named: "detailTextColor") ?? UIColor.gray
        static let notificationContent =    UIColor(rgb: 0x868686)
        static let notificationTimestamp =  UIColor(rgb: 0xADADAD)

        static var reply: UIColor {
            return text.default
        }

        static var placeholder: UIColor {
            return text.detail
        }
    }

    struct tint {
        static let `default` = #colorLiteral(red: 1, green: 0.1490196078, blue: 0.3058823529, alpha: 1)
        static let system = #colorLiteral(red: 0, green: 0.4623456597, blue: 1, alpha: 1)
    }
}
