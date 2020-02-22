//
//  NSMutableAttributedString+About.swift
//  FBTT
//
//  Created by Christoph on 6/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension NSMutableAttributedString {

    convenience init(from about: About) {
        let name = about.nameOrIdentity
        self.init(string: name)
        let range = NSRange(location: 0, length: name.count)
        self.addAttribute(NSAttributedString.Key.link, value: about.identity, range: range)
    }
}
