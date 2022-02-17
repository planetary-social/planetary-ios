//
//  String+Markdown.swift
//  Planetary
//
//  Created by Martin Dutra on 4/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Down
import Logger

extension String {
    
    func decodeMarkdown(small: Bool = false) -> NSAttributedString {
        let down = Down(markdownString: self)
        let styler = MarkdownStyler(small: small)
        do {
            let attributedString = try down.toAttributedString(.default,
                                                               styler: styler)
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
            addHashtagsLinks(in: mutableAttributedString, styler: styler)
            addUnformattedLinks(in: mutableAttributedString, styler: styler)
            addUnformattedMentions(in: mutableAttributedString, styler: styler)
            return mutableAttributedString
        } catch let error {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return NSAttributedString(string: self)
        }
    }

    func addHashtagsLinks(in mutableAttributedString: NSMutableAttributedString, styler: DownStyler) {
        let hashtags = mutableAttributedString.string.hashtagsWithRanges()
        for (hashtag, range) in hashtags.reversed() {
            let attributedHashtag = mutableAttributedString.attributedSubstring(from: range)
            let mutableAttributedHashtag = NSMutableAttributedString(attributedString: attributedHashtag)
            styler.style(link: mutableAttributedHashtag, title: hashtag.string, url: hashtag.string)
            mutableAttributedString.replaceCharacters(in: range, with: mutableAttributedHashtag)
        }
    }

    func addUnformattedLinks(in mutableAttributedString: NSMutableAttributedString, styler: DownStyler) {
        let string = mutableAttributedString.string
        let types: NSTextCheckingResult.CheckingType = [.link]
        let detector = try! NSDataDetector(types: types.rawValue)
        let range = NSRange(location: 0, length: mutableAttributedString.length)
        detector.enumerateMatches(in: string, options: [], range: range) { (result, _, _) in
            guard let result = result else {
                return
            }
            switch result.resultType {
            case .link:
                let url = result.url!
                let range = result.range

                let currentAttributes = mutableAttributedString.attributes(at: range.location, effectiveRange: nil)
                guard !currentAttributes.keys.contains(.link) else {
                    return
                }

                let attributedLink = mutableAttributedString.attributedSubstring(from: result.range)
                let mutableAttributedLink = NSMutableAttributedString(attributedString: attributedLink)
                styler.style(link: mutableAttributedLink, title: nil, url: url.absoluteString)
                mutableAttributedString.replaceCharacters(in: range, with: mutableAttributedLink)
            default:
                return
            }
        }
    }
    
    func addUnformattedMentions(in mutableAttributedString: NSMutableAttributedString, styler: DownStyler) {
        let string = mutableAttributedString.string
        let range = NSRange(location: 0, length: string.utf16.count)
        let pattern = "[@%&][a-zA-Z0-9+/=]{44}\\.[a-z0-9]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            let error = AppError.unexpected
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return
        }
        regex.enumerateMatches(in: string, options: [], range: range) { (result, _, _) in
            guard let result = result else {
                return
            }
            let range = result.range
            let currentAttributes = mutableAttributedString.attributes(at: range.location,
                                                                       effectiveRange: nil)
            guard !currentAttributes.keys.contains(.link) else {
                return
            }
            let attributedLink = mutableAttributedString.attributedSubstring(from: range)
            let mutableAttributedLink = NSMutableAttributedString(attributedString: attributedLink)
            styler.style(link: mutableAttributedLink, title: nil, url: attributedLink.string)
            mutableAttributedString.replaceCharacters(in: range, with: mutableAttributedLink)
        }
    }
    
}
