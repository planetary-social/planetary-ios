//
//  MarkdownTests.swift
//  UnitTests
//
//  Created by Martin Dutra on 4/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import XCTest

class MarkdownTests: XCTestCase {
    
    func test_attributedStringToMarkdown() {
        let attributedString = NSMutableAttributedString(string: "test ")
        attributedString.append(Mention(link: "identity", name: "identity").attributedString)
        attributedString.append(NSAttributedString(string: " "))
        attributedString.append(Hashtag.named("test").attributedString)
        XCTAssertTrue(attributedString.encodeMarkdown() == "test [identity](identity) #test")
    }
    
    func test_decodeManyChannels() {
        let markdown = "this is a test #channel1 and another #channel2 plus a third #channel3"
        let attributedString = markdown.decodeMarkdown()
        XCTAssertNotNil(attributedString)
        
        let hashtags = attributedString.mentions()
        XCTAssertEqual(hashtags.count, 3)
        XCTAssertEqual(hashtags[0].name, "#channel1")
        XCTAssertEqual(hashtags[0].link, "#channel1")
        XCTAssertEqual(hashtags[1].name, "#channel2")
        XCTAssertEqual(hashtags[1].link, "#channel2")
        XCTAssertEqual(hashtags[2].name, "#channel3")
        XCTAssertEqual(hashtags[2].link, "#channel3")
    }
   
    func test_decodeManyLinks() {
        let markdown = "This is a test for [one](one.com) link plus a [second](second.com) link in markdown."
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 2)
        XCTAssertEqual(mentions[0].name, "one")
        XCTAssertEqual(mentions[0].link, "one.com")
        XCTAssertEqual(mentions[1].name, "second")
        XCTAssertEqual(mentions[1].link, "second.com")
    }
    
    func test_decodeLinkWithParenthesisInName() {
        let markdown = "[@SoapDog (SPX)](@0xkjAty6RSr5uhbAvi0rbVR2g9Bz+89qiKth48ECQBE=.ed25519)"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "@SoapDog (SPX)")
        XCTAssertEqual(mentions[0].link, "@0xkjAty6RSr5uhbAvi0rbVR2g9Bz+89qiKth48ECQBE=.ed25519")
    }
    
    func test_decodeLinkWithIdentifier() {
        let markdown = "Hey [@christoph@verse](@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519)!\n\nNext week sounds great. I'd love to help out. I've been using more the iPhone I acquired during this quest, and I'd love to get a working SSB client on it as well."
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "@christoph@verse")
        XCTAssertEqual(mentions[0].link, "@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519")
    }
    
    func test_decodeImageWithIdentifier() {
        let markdown = "![we-must-get-back-to-oakland-at-once.jpg](&amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw=.sha256) \"We must get back to Oakland at once!\")"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "we-must-get-back-to-oakland-at-once.jpg")
        XCTAssertEqual(mentions[0].link, "&amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw=.sha256")
    }
    
    func test_decodeTitle() {
        let markdown = "# This is a title\n\nAnd this is a the body"
        let attributedString = markdown.decodeMarkdown()
        XCTAssertNotNil(attributedString)
    }
    
    func test_decodeAwfulLink() {
        let markdown = "[**\\!bang**](https://duckduckgo.com/bang)"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "!bang")
        XCTAssertEqual(mentions[0].link, "https://duckduckgo.com/bang")
    }

    func test_decodeLinkWithoutFormat() {
        let markdown = "This is a link http://www.one.com without format"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].link, "http://www.one.com")
    }

    func test_decodeTwoDifferentLinks() {
        let markdown = "This is a test for [one](http://www.one.com) link in markdown plus a http://www.second.com link not formatted."
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 2)
        XCTAssertEqual(mentions[0].name, "one")
        XCTAssertEqual(mentions[0].link, "http://www.one.com")
        XCTAssertEqual(mentions[1].link, "http://www.second.com")
    }

    func test_decodeLinkWithUrlAsName() {
        let markdown = "This is a test for [http://www.one.com](http://www.second.com) link in markdown"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "http://www.one.com")
        XCTAssertEqual(mentions[0].link, "http://www.second.com")
    }
    
    func test_decodeIdentifiersWithoutLink() {
        let markdown = """
    Hey @8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519
and @34sT5kRdt1HxkueXfRsIU4fbYkjapDztCHgjNjiCnDs=.ed25519!\n
\n
Next week sounds great.
I'd love to help out.
I've been using more the iPhone I acquired during this quest, and I'd love to get a working SSB client on it as well.
"""
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 2)
        XCTAssertEqual(mentions[0].name, "@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519")
        XCTAssertEqual(mentions[0].link, "@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519")
        XCTAssertEqual(mentions[1].name, "@34sT5kRdt1HxkueXfRsIU4fbYkjapDztCHgjNjiCnDs=.ed25519")
        XCTAssertEqual(mentions[1].link, "@34sT5kRdt1HxkueXfRsIU4fbYkjapDztCHgjNjiCnDs=.ed25519")
    }
    
    func test_decodeLinkwithIdentifierWithoutFormat() {
        let markdown = """
    This is a link https://planetary.link/@/+6dlGNjBoNbmOkK08U43xfodyZ2LHHOwcsVpfRv4vg=.ed25519
without format and with an identifier in the middle
"""
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].link, "https://planetary.link/@/+6dlGNjBoNbmOkK08U43xfodyZ2LHHOwcsVpfRv4vg=.ed25519")
        
    }

}
