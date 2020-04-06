//
//  String+Markdown.swift
//  Planetary
//
//  Created by Martin Dutra on 4/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Down
// import SwiftyMarkdown

extension String {
    
    func decodeMarkdown() -> NSAttributedString {
        let down = Down(markdownString: self)
        do {
            let attributedString = try down.toAttributedString(.default, styler: DownStyler())
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
            mutableAttributedString.replaceHashtagsWithLinkAttributes()
            return mutableAttributedString
        } catch let error {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return NSAttributedString(string: self)
        }
    }
//
//    func decodeMarkdown() -> NSAttributedString? {
//        let smd = SwiftyMarkdown(string: self)
//        let string = smd.attributedString()
//        let mas = NSMutableAttributedString(attributedString: string)
//        mas.replaceHashtagsWithLinkAttributes()
//        return mas
//    }
    
}
