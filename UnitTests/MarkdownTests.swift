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
        
        let hashtags = attributedString.hashtags()
        XCTAssertEqual(hashtags.count, 3)
        XCTAssertEqual(hashtags[0], Hashtag(name: "channel1"))
        XCTAssertEqual(hashtags[1], Hashtag(name: "channel2"))
        XCTAssertEqual(hashtags[2], Hashtag(name: "channel3"))
        
//        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
//        mutableAttributedString.removeHashtagLinkAttributes()
//        XCTAssertTrue(mutableAttributedString.hashtags().isEmpty)
//        XCTAssertTrue(mutableAttributedString.string == markdown)
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
    
}
