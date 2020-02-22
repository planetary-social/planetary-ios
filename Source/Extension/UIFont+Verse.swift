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

    let peerCount = UIFont.systemFont(ofSize: 12, weight: .regular)
    let peerCountBold = UIFont.systemFont(ofSize: 12, weight: .semibold)

    let aboutCellName = UIFont.systemFont(ofSize: 15, weight: .semibold)
    let aboutCellIdentity = UIFont.systemFont(ofSize: 15, weight: .regular)

    let pillButton = UIFont.systemFont(ofSize: 14, weight: .medium)

    // MARK: NSAttributedString definitions

    var postAttributes: [NSAttributedString.Key: Any] {
        let font = UIFont.verse.post
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 1
        return [.font: font,
                .kern: kerning(7, font: font),
                .foregroundColor: UIColor.text.default,
                .paragraphStyle: style]
    }

    var largePostAttributes: [NSAttributedString.Key: Any] {
        let font = UIFont.verse.postLarge
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        return [.font: font,
                .kern: kerning(6, font: font),
                .foregroundColor: UIColor.text.default,
                .paragraphStyle: style]
    }

    var profileBioAttributes: [NSAttributedString.Key: Any] {
        // Tom said he might like to be able to customize these in the future,
        // but that for now they should be the same as post.
        return self.postAttributes
    }

    // this translates the `tracking` from an Adobe-compatible value
    // based on the spacing and the font size
    private func kerning(_ tracking: CGFloat, font: UIFont) -> CGFloat {
        return font.pointSize * tracking / 1000
    }
}

extension UIFont {

    static let verse = VerseFonts()

    static func paragraphStyleAttribute(lineSpacing: CGFloat) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return [.paragraphStyle: style]
    }
}
