//
//  UIFont+Verse.swift
//  FBTT
//
//  Created by Christoph on 7/3/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

struct VerseFonts {

    let post = UIFont.systemFont(ofSize: 16, weight: .regular)
    let postLarge = UIFont.systemFont(ofSize: 18, weight: .regular)
    let newPost = UIFont.systemFont(ofSize: 19, weight: .regular)
    let reply = UIFont.systemFont(ofSize: 15, weight: .regular)

    let followCountView = UIFont.systemFont(ofSize: 15, weight: .regular)
    let followCountViewBold = UIFont.systemFont(ofSize: 15, weight: .semibold)

    let floatingRefresh = UIFont.systemFont(ofSize: 10, weight: .regular)
    
    let peerCount = UIFont.systemFont(ofSize: 12, weight: .regular)
    let peerCountBold = UIFont.systemFont(ofSize: 12, weight: .semibold)

    let aboutCellName = UIFont.systemFont(ofSize: 15, weight: .semibold)
    let aboutCellIdentity = UIFont.systemFont(ofSize: 15, weight: .regular)

    let pillButton = UIFont.systemFont(ofSize: 14, weight: .medium)
}

struct PostFonts {
    
    var body = UIFont.systemFont(ofSize: 16, weight: .regular)
    var heading1 = UIFont.boldSystemFont(ofSize: 26)
    var heading2 = UIFont.boldSystemFont(ofSize: 22)
    var heading3 = UIFont.boldSystemFont(ofSize: 18)
    var code = UIFont.systemFont(ofSize: 16, weight: .regular)
    var listItemPrefix = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)

    init() {
        if #available(iOS 13, *) {
            self.code = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        }
    }
}

struct SmallPostFonts {

    var header = UIFont.systemFont(ofSize: 10, weight: .semibold)
    
    var body = UIFont.systemFont(ofSize: 14, weight: .regular)
    var heading1 = UIFont.systemFont(ofSize: 14, weight: .heavy)
    var heading2 = UIFont.systemFont(ofSize: 14, weight: .bold)
    var heading3 = UIFont.systemFont(ofSize: 14, weight: .semibold)
    var bigHeading = UIFont.systemFont(ofSize: 14, weight: .semibold)
    var code = UIFont.systemFont(ofSize: 14, weight: .regular)
    var listItemPrefix = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)

    init() {
        if #available(iOS 13, *) {
            self.code = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        }
    }
}

extension UIFont {

    static let verse = VerseFonts()
    static let post = PostFonts()
    static let smallPost = SmallPostFonts()
    
    static func paragraphStyleAttribute(lineSpacing: CGFloat) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return [.paragraphStyle: style]
    }
}
