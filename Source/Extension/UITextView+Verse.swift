//
//  UITextView+Verse.swift
//  FBTT
//
//  Created by Christoph on 7/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UITextView {

    static func forPostsAndReplies() -> UITextView {
        let view = UITextView.forAutoLayout()
        view.configureForPostsAndReplies()
        return view
    }

    func configureForPostsAndReplies() {
        self.autocapitalizationType = .sentences
        self.autocorrectionType = .yes
        self.isEditable = true
        self.spellCheckingType = .yes
    }
}
