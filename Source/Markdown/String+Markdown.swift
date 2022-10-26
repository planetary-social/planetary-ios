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
import CrashReporting

extension String {

    func parseMarkdown() -> AttributedString {
        func findHashtags(in markdown: String) throws -> String {
            let regex = "(?:^|\\s)(?<hashtag>#[a-z0-9]+|#[a-z0-9]+$)"
            let regularExpression = try NSRegularExpression(pattern: regex)
            if let match = regularExpression.firstMatch(in: markdown, range: NSRange(location: 0, length: markdown.utf16.count)) {
                if let range = Range(match.range(withName: "hashtag"), in: markdown) {
                    let replacement = "planetary://planetary.link/\(markdown[range])"
                    return try findHashtags(in: markdown.replacingCharacters(in: range, with: replacement))
                }
            }
            return markdown
        }

        func findMentions(in markdown: String) throws -> String {
            let regex = "(?:^|\\s)(?<mention>[@%&][a-zA-Z0-9+/=]{44}\\.[a-z0-9]+)"
            let regularExpression = try NSRegularExpression(pattern: regex)
            if let match = regularExpression.firstMatch(in: markdown, range: NSRange(location: 0, length: markdown.utf16.count)) {
                if let range = Range(match.range(withName: "mention"), in: markdown) {
                    let replacement = "planetary://planetary.link/\(markdown[range])"
                    return try findMentions(in: markdown.replacingCharacters(in: range, with: replacement))
                }
            }
            return markdown
        }

        func findUnformattedLinks(in markdown: String) -> String {
            do {
                var result = try findMentions(in: markdown)
                result = try findHashtags(in: result)
                return result
            } catch {
                return markdown
            }
        }

        do {
            var attributed = try AttributedString(markdown: findUnformattedLinks(in: self))
            for run in attributed.runs {
                if let link = run.attributes.link {
                    if let url = URL(string: findUnformattedLinks(in: link.absoluteString)) {
                        attributed[run.range].link = url
                    }
                }
            }
            return attributed
        } catch {
            return AttributedString()
        }
    }

    func decodeMarkdown(small: Bool = false, host: String = "") -> NSAttributedString {
        let down = Down(markdownString: self)
        let styler = MarkdownStyler(small: small)
        do {
            let attributedString = try down.toAttributedString(.default,
                                                               styler: styler)
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
            fixFormattedLinks(in: mutableAttributedString, styler: styler, host: host)
            addHashtagsLinks(in: mutableAttributedString, styler: styler, host: host)
            addUnformattedLinks(in: mutableAttributedString, styler: styler)
            addUnformattedMentions(in: mutableAttributedString, styler: styler, host: host)
            return mutableAttributedString
        } catch {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return NSAttributedString(string: self)
        }
    }

    func fixFormattedLinks(in mutableAttributedString: NSMutableAttributedString, styler: DownStyler, host: String = "") {
        let wholeRange = NSRange(mutableAttributedString.string.startIndex..., in: mutableAttributedString.string)
        mutableAttributedString.enumerateAttribute(.link, in: wholeRange) { value, range, pointee in
            guard let url = value as? String else {
                return
            }
            if url.isValidIdentifier {
                mutableAttributedString.removeAttribute(.link, range: range)
                mutableAttributedString.addAttribute(.link, value: url.deepLink, range: range)
            }
        }
    }

    func addHashtagsLinks(in mutableAttributedString: NSMutableAttributedString, styler: DownStyler, host: String = "") {
        let hashtags = mutableAttributedString.string.hashtagsWithRanges()
        for (hashtag, range) in hashtags.reversed() {
            let attributedHashtag = mutableAttributedString.attributedSubstring(from: range)
            let mutableAttributedHashtag = NSMutableAttributedString(attributedString: attributedHashtag)
            styler.style(link: mutableAttributedHashtag, title: hashtag.string, url: host + hashtag.string)
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
    
    func addUnformattedMentions(in mutableAttributedString: NSMutableAttributedString, styler: DownStyler, host: String = "") {
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
            styler.style(link: mutableAttributedLink, title: nil, url: host + attributedLink.string)
            mutableAttributedString.replaceCharacters(in: range, with: mutableAttributedLink)
        }
    }
}
