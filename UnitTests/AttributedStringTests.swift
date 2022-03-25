//
//  AttributedStringTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 7/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

class AttributedStringTests: XCTestCase {

    func test_aboutToAttributedStringToMarkdown() {

        let about = About(about: Identity.testIdentity, name: "test")
        let string = NSMutableAttributedString(from: about)
        let markdown = "[test](\(Identity.testIdentity))"

        // attributed string with link into mentions
        let mentions = string.mentions()
        XCTAssert(mentions.count == 1)
        XCTAssert(mentions.first?.name == "test")
        XCTAssert(mentions.first?.link == Identity.testIdentity)

        // transcode to markdown
        // [I'm an inline-style link](https://www.google.com)
        let markdowns = mentions.markdowns()
        XCTAssert(markdowns.count == 1)
        XCTAssert(markdowns.first == markdown)
    }

    func test_mentionAttributedStringToMarkdown() {
        let string = NSMutableAttributedString(string: "this is a test ")
        let mention = Mention(link: "identity", name: "identity")
        string.append(mention.attributedString)
        let markdown = string.markdown
        XCTAssertTrue(markdown == "this is a test [identity](identity)")
    }

    func test_hashtagToAttributedString() {
        let hashtag = Hashtag.named("channel")
        let string = hashtag.attributedString
        let hashtags = string.hashtags()
        XCTAssertTrue(hashtags.count == 1)
        XCTAssertTrue(hashtags[0].name == "channel")
        XCTAssertTrue(hashtags[0].string == "#channel")
    }

    func test_stringHashtagsAndRanges() {
        let string = "this is a test #channel1 and another #channel2\nplus a third #channel3"
        let results = string.hashtagsWithRanges()
        XCTAssertTrue(results.count == 3)
        XCTAssertTrue(results[0].0.name == "channel1")
        XCTAssertTrue(results[0].1 == NSRange(location: 15, length: 9))
        XCTAssertTrue(results[1].0.name == "channel2")
        XCTAssertTrue(results[1].1 == NSRange(location: 37, length: 9))
        XCTAssertTrue(results[2].0.name == "channel3")
    }

    // https://app.asana.com/0/914798787098068/1131129772445606/f
    // Fixes this issue, and is referenced for historical purposes.
    func test_stringAlphaNumericHashtagsOnly() {
        let string = """
                     #Q23AS9D0APQQ2
                     Q23AS9D0APQQ2
                     #111111
                     #aaaaaa
                     #q2IasK231@!@!#_+123
                     #asdas12312...1231@asda___213-1
                     #asdas123121231asda2131
                     asdas123121231asda2131

                     hello #hashtag my old friend

                     #1234567890 #1234abcd1234 #abcd1234abcd #abcdefghijkl
                     #1234abcdefgh
                     """
        let expected = 10
        let count = string.hashtags().count
        XCTAssertTrue(count == expected, "Expected \(expected) hashtags, got \(count)")
    }

    func test_hashtagAttributedStringToMarkdown() {
        let markdown = "this is a test #channel1 and another #channel2 plus a third #channel3"
        let attributedString = markdown.decodeMarkdown()
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        let hashtags = mutableAttributedString.replaceHashtagsWithLinkAttributes().hashtags()
        XCTAssertTrue(hashtags.count == 3)
        mutableAttributedString.removeHashtagLinkAttributes()
        XCTAssertTrue(mutableAttributedString.hashtags().isEmpty)
        XCTAssertTrue(mutableAttributedString.string == markdown)
    }

    func test_attributedStringToMarkdown() {
        let attributedString = NSMutableAttributedString(string: "test ")
        attributedString.append(Mention(link: "identity", name: "identity").attributedString)
        attributedString.append(NSAttributedString(string: " "))
        attributedString.append(Hashtag.named("test").attributedString)
        XCTAssertTrue(attributedString.encodeMarkdown() == "test [identity](identity) #test")
    }
}
