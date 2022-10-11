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
//
// These colors are old. The correct way to add colors now is to add them to Assets.xcassets and SwiftGen will generate
// accessors like these.
extension UIColor {
    
    static let splashBackground = UIColor(named: "splashBackgroundColor", in: Bundle.current, compatibleWith: nil) ?? UIColor.white

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
