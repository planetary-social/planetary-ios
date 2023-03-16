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

    func parseMarkdown(fontStyle: MarkdownStyler.FontStyle = .regular) -> AttributedString {
        do {
            let markdown = fixMarkdownIfNeeded(removePlanetaryAttachmentLinks(in: self))
            let down = Down(markdownString: markdown)
            let styler = MarkdownStyler(fontStyle: fontStyle)
            var attributed = AttributedString(try down.toAttributedString(.default, styler: styler))
            for attributedRun in attributed.runs {
                if let link = attributedRun.attributes.link ?? attributedRun.attributes.imageURL {
                    if let url = URL(string: fixLinkIfNeeded(link.absoluteString)) {
                        attributed[attributedRun.range].link = url
                    }
                }
            }
            return attributed
        } catch {
            return AttributedString()
        }
    }

    /// Find all hashtags in a given string and replaces them with deeplinks
    private func findHashtags(in markdown: String, usingMarkdownLinks: Bool) throws -> String {
        let regex = "(?:^|\\s)(?<hashtag>#[\\p{L}\\d-]+|#[\\p{L}\\d-]+$)"
        let regularExpression = try NSRegularExpression(pattern: regex)
        let wholeRange = NSRange(location: 0, length: markdown.utf16.count)
        if let match = regularExpression.firstMatch(in: markdown, range: wholeRange) {
            if let range = Range(match.range(withName: "hashtag"), in: markdown) {
                let hashtag = "\(markdown[range])"
                let link = hashtag.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved) ?? hashtag
                let replacement: String
                if usingMarkdownLinks {
                    replacement = "[\(hashtag)](planetary://planetary.link/\(link))"
                } else {
                    replacement = "planetary://planetary.link/\(link)"
                }
                return try findHashtags(
                    in: markdown.replacingCharacters(in: range, with: replacement),
                    usingMarkdownLinks: usingMarkdownLinks
                )
            }
        }
        return markdown
    }

    /// Find all mentions in a given string and replaces them with deeplinks
    private func findMentions(in markdown: String, usingMarkdownLinks: Bool) throws -> String {
        let regex = "(?:^|\\s)(?<mention>[@%&][a-zA-Z0-9+/=]{44}\\.[a-z0-9]+)"
        let regularExpression = try NSRegularExpression(pattern: regex)
        let wholeRange = NSRange(location: 0, length: markdown.utf16.count)
        if let match = regularExpression.firstMatch(in: markdown, range: wholeRange) {
            if let range = Range(match.range(withName: "mention"), in: markdown) {
                let mention = "\(markdown[range])"
                let link = mention.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved) ?? mention
                let replacement: String
                if usingMarkdownLinks {
                    replacement = "[\(mention)](planetary://planetary.link/\(link))"
                } else {
                    replacement = "planetary://planetary.link/\(link)"
                }
                return try findMentions(
                    in: markdown.replacingCharacters(in: range, with: replacement),
                    usingMarkdownLinks: usingMarkdownLinks
                )
            }
        }
        return markdown
    }

    /// Find all links in a given string and replaces them with markdown formatted links
    private func findUnformattedLinks(in markdown: String) throws -> String {
        // swiftlint:disable line_length
        let regex = "(?:^|\\s)(?<link>((http|https|planetary|ssb)?:\\/\\/.)?(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[a-z]{2,6}\\b([-a-zA-Z0-9@:%_\\+.~#?&//=]*))"
        // swiftlint:enable line_length
        let regularExpression = try NSRegularExpression(pattern: regex)
        let wholeRange = NSRange(location: 0, length: markdown.utf16.count)
        if let match = regularExpression.firstMatch(in: markdown, range: wholeRange) {
            if let range = Range(match.range(withName: "link"), in: markdown) {
                let link = "\(markdown[range])"
                let replacement = "[\(link)](\(link))"
                return try findUnformattedLinks(in: markdown.replacingCharacters(in: range, with: replacement))
            }
        }
        return markdown
    }

    /// Replaces all mentions, hashtags and links with markdown formatted links
    private func fixMarkdownIfNeeded(_ markdown: String) -> String {
        do {
            var result = try findMentions(in: markdown, usingMarkdownLinks: true)
            result = try findHashtags(in: result, usingMarkdownLinks: true)
            result = try findUnformattedLinks(in: result)
            return result
        } catch {
            return markdown
        }
    }

    /// Returns a deeplink when needed
    private func fixLinkIfNeeded(_ link: String) -> String {
        do {
            var result = try findMentions(in: link, usingMarkdownLinks: false)
            result = try findHashtags(in: result, usingMarkdownLinks: false)
            return result
        } catch {
            return link
        }
    }

    /// Removes the planetary attachment links at the end
    private func removePlanetaryAttachmentLinks(in markdown: String) -> String {
        func checkSubstring(_ substring: String) -> String? {
            guard let attMatch = markdown.range(of: substring) else {
                return nil
            }
            let before = markdown[markdown.startIndex..<attMatch.lowerBound]
            return String(before)
        }
        if let trimmedString = checkSubstring("\n\n![planetary attachment no.1") {
            return trimmedString
        } else if let trimmedString = checkSubstring("\n![planetary attachment no.1") {
            return trimmedString
        }
        return markdown
    }
    
    func decodeMarkdown(small: Bool = false, host: String = "") -> NSAttributedString {
        let down = Down(markdownString: self)
        let styler = MarkdownStyler(fontStyle: small ? .compact : .thread)
        do {
            let attributedString = try down.toAttributedString(.default, styler: styler)
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
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

    func fixFormattedLinks(
        in mutableAttributedString: NSMutableAttributedString,
        styler: DownStyler,
        host: String = ""
    ) {
        let wholeRange = NSRange(mutableAttributedString.string.startIndex..., in: mutableAttributedString.string)
        mutableAttributedString.enumerateAttribute(.link, in: wholeRange) { value, range, _ in
            guard let url = value as? String else {
                return
            }
            if url.isValidIdentifier, let deeplink = url.deepLink {
                mutableAttributedString.removeAttribute(.link, range: range)
                mutableAttributedString.addAttribute(.link, value: deeplink, range: range)
            }
        }
    }

    func addHashtagsLinks(
        in mutableAttributedString: NSMutableAttributedString,
        styler: DownStyler,
        host: String = ""
    ) {
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
        // swiftlint:disable legacy_objc_type
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            return
        }
        // swiftlint:enable legacy_objc_type
        let range = NSRange(location: 0, length: mutableAttributedString.length)
        detector.enumerateMatches(in: string, options: [], range: range) { (result, _, _) in
            guard let result = result else {
                return
            }
            switch result.resultType {
            case .link:
                guard let url = result.url else {
                    return
                }
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
    
    func addUnformattedMentions(
        in mutableAttributedString: NSMutableAttributedString,
        styler: DownStyler,
        host: String = ""
    ) {
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
            let currentAttributes = mutableAttributedString.attributes(at: range.location, effectiveRange: nil)
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
