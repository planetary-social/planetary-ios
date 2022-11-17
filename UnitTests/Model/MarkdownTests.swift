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

    func testParseChannelWithDash() throws {
        let markdown = "this is a test #chan-nel1 and another #chan_nel2 plus a third #channel3"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 3)
        let firstLink = try XCTUnwrap(links[0])
        let secondLink = try XCTUnwrap(links[1])
        let thirdLink = try XCTUnwrap(links[2])
        XCTAssertEqual(firstLink.url, URL(string: "planetary://planetary.link/%23chan-nel1"))
        XCTAssertEqual(secondLink.url, URL(string: "planetary://planetary.link/%23chan_nel2"))
        XCTAssertEqual(thirdLink.url, URL(string: "planetary://planetary.link/%23channel3"))
        XCTAssertEqual(firstLink.name, "#chan-nel1")
        XCTAssertEqual(secondLink.name, "#chan_nel2")
        XCTAssertEqual(thirdLink.name, "#channel3")
    }

    func testParseChannelWithCamelCase() throws {
        let markdown = "this is a test #sameAs"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let firstLink = try XCTUnwrap(links[0])
        XCTAssertEqual(firstLink.url, URL(string: "planetary://planetary.link/%23sameAs"))
        XCTAssertEqual(firstLink.name, "#sameAs")
    }

    func testParseManyChannels() throws {
        let markdown = "this is a test #channel1 and another #channel2 plus a third #channel3"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 3)
        let firstLink = try XCTUnwrap(links[0])
        let secondLink = try XCTUnwrap(links[1])
        let thirdLink = try XCTUnwrap(links[2])
        XCTAssertEqual(firstLink.url, URL(string: "planetary://planetary.link/%23channel1"))
        XCTAssertEqual(secondLink.url, URL(string: "planetary://planetary.link/%23channel2"))
        XCTAssertEqual(thirdLink.url, URL(string: "planetary://planetary.link/%23channel3"))
        XCTAssertEqual(firstLink.name, "#channel1")
        XCTAssertEqual(secondLink.name, "#channel2")
        XCTAssertEqual(thirdLink.name, "#channel3")
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

    func testParseManyLinks() throws {
        let markdown = "This is a test for [one](one.com) link plus a [second](second.com) link in markdown."
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 2)
        let firstLink = try XCTUnwrap(links[0])
        let secondLink = try XCTUnwrap(links[1])
        XCTAssertEqual(firstLink.url, URL(string: "one.com"))
        XCTAssertEqual(secondLink.url, URL(string: "second.com"))
        XCTAssertEqual(firstLink.name, "one")
        XCTAssertEqual(secondLink.name, "second")
    }
    
    func test_decodeLinkWithParenthesisInName() {
        let markdown = "[@SoapDog (SPX)](@0xkjAty6RSr5uhbAvi0rbVR2g9Bz+89qiKth48ECQBE=.ed25519)"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "@SoapDog (SPX)")
        XCTAssertEqual(mentions[0].link, "@0xkjAty6RSr5uhbAvi0rbVR2g9Bz+89qiKth48ECQBE=.ed25519")
    }

    func testParseLinkWithParenthesisInName() throws {
        let markdown = "[@SoapDog (SPX)](@0xkjAty6RSr5uhbAvi0rbVR2g9Bz+89qiKth48ECQBE=.ed25519)"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.url, URL(string: "planetary://planetary.link/%400xkjAty6RSr5uhbAvi0rbVR2g9Bz%2B89qiKth48ECQBE%3D.ed25519"))
        XCTAssertEqual(link.name, "@SoapDog (SPX)")
    }
    
    func test_decodeLinkWithIdentifier() {
        let markdown = "Hey [@christoph@verse](@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519)!\n\nNext week sounds great. I'd love to help out. I've been using more the iPhone I acquired during this quest, and I'd love to get a working SSB client on it as well."
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "@christoph@verse")
        XCTAssertEqual(mentions[0].link, "@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519")
    }

    func testParseLinkWithIdentifier() throws {
        let markdown = "Hey [@christoph@verse](@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519)!"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.url, URL(string: "planetary://planetary.link/%408Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn%2FM%3D.ed25519"))
        XCTAssertEqual(link.name, "@christoph@verse")
    }

    func testParseMessageLink() throws {
        let markdown = "may have found a solution: %Ogr2+mPA0PwJEKX4qhKNzYykOxMedvaMDjHB8YT49F4=.sha256"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.url, URL(string: "planetary://planetary.link/%25Ogr2%2BmPA0PwJEKX4qhKNzYykOxMedvaMDjHB8YT49F4%3D.sha256"))
        XCTAssertEqual(link.name, "%Ogr2+mPA0PwJEKX4qhKNzYykOxMedvaMDjHB8YT49F4=.sha256")
    }

    func testParseIdentifierWithoutLink() throws {
        let markdown = "Hey @8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.url, URL(string: "planetary://planetary.link/%408Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn%2FM%3D.ed25519"))
        XCTAssertEqual(link.name, "@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519")
    }
    
    func test_decodeImageWithIdentifier() {
        let markdown = "![we-must-get-back-to-oakland-at-once.jpg](&amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw=.sha256) \"We must get back to Oakland at once!\")"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "we-must-get-back-to-oakland-at-once.jpg")
        XCTAssertEqual(mentions[0].link, "&amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw=.sha256")
    }

    func testParseImageWithIdentifier() throws {
        let markdown = "![we-must-get-back-to-oakland-at-once.jpg](&amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw=.sha256) \"We must get back to Oakland at once!\")"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.url, URL(string: "planetary://planetary.link/%26amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw%3D.sha256"))
        XCTAssertEqual(link.name, "we-must-get-back-to-oakland-at-once.jpg")
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

    func testParseAwfulLink() throws {
        let markdown = "[**\\!bang**](https://duckduckgo.com/bang)"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.name, "!bang")
        XCTAssertEqual(link.url, URL(string: "https://duckduckgo.com/bang"))
    }

    func test_decodeLinkWithoutFormat() {
        let markdown = "This is a link http://www.one.com without format"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].link, "http://www.one.com")
    }

    func testParseLinkWithoutFormat() throws {
        let markdown = "This is a link http://www.one.com without format"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.name, "http://www.one.com")
        XCTAssertEqual(link.url, URL(string: "http://www.one.com"))
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

    func testParseTwoDifferentLinks() throws {
        let markdown = "This is a test for [one](http://www.one.com) link in markdown plus a http://www.second.com link not formatted."
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 2)
        let firstLink = try XCTUnwrap(links[0])
        let secondLink = try XCTUnwrap(links[1])
        XCTAssertEqual(firstLink.name, "one")
        XCTAssertEqual(firstLink.url, URL(string: "http://www.one.com"))
        XCTAssertEqual(secondLink.name, "http://www.second.com")
        XCTAssertEqual(secondLink.url, URL(string: "http://www.second.com"))
    }

    func test_decodeLinkWithUrlAsName() {
        let markdown = "This is a test for [http://www.one.com](http://www.second.com) link in markdown"
        let attributedString = markdown.decodeMarkdown()
        let mentions = attributedString.mentions()
        XCTAssertEqual(mentions.count, 1)
        XCTAssertEqual(mentions[0].name, "http://www.one.com")
        XCTAssertEqual(mentions[0].link, "http://www.second.com")
    }

    func testParseLinkWithUrlAsName() throws {
        let markdown = "This is a test for [http://www.one.com](http://www.second.com) link in markdown"
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.name, "http://www.one.com")
        XCTAssertEqual(link.url, URL(string: "http://www.second.com"))
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

    func testParseIdentifiersWithoutLink() throws {
        let markdown = """
Hey @8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519
and @34sT5kRdt1HxkueXfRsIU4fbYkjapDztCHgjNjiCnDs=.ed25519!\n
\n
Next week sounds great.
I'd love to help out.
I've been using more the iPhone I acquired during this quest, and I'd love to get a working SSB client on it as well.
"""
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 2)
        let firstLink = try XCTUnwrap(links[0])
        let secondLink = try XCTUnwrap(links[1])
        XCTAssertEqual(firstLink.name, "@8Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn/M=.ed25519")
        XCTAssertEqual(firstLink.url, URL(string: "planetary://planetary.link/%408Y7zrkRdt1HxkueXjdwIU4fbYkjapDztCHgjNjiCn%2FM%3D.ed25519"))
        XCTAssertEqual(secondLink.name, "@34sT5kRdt1HxkueXfRsIU4fbYkjapDztCHgjNjiCnDs=.ed25519")
        XCTAssertEqual(secondLink.url, URL(string: "planetary://planetary.link/%4034sT5kRdt1HxkueXfRsIU4fbYkjapDztCHgjNjiCnDs%3D.ed25519"))
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

    func testParseLinkwithIdentifierWithoutFormat() throws {
        let markdown = """
This is a link https://planetary.link/%40%2F%2B6dlGNjBoNbmOkK08U43xfodyZ2LHHOwcsVpfRv4vg%3D.ed25519 without
format and with an identifier in the middle
"""
        let attributedString = markdown.parseMarkdown()
        let links = parseLinks(in: attributedString)
        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links[0])
        XCTAssertEqual(link.name, "https://planetary.link/%40%2F%2B6dlGNjBoNbmOkK08U43xfodyZ2LHHOwcsVpfRv4vg%3D.ed25519")
        XCTAssertEqual(link.url, URL(string: "https://planetary.link/%40%2F%2B6dlGNjBoNbmOkK08U43xfodyZ2LHHOwcsVpfRv4vg%3D.ed25519"))
    }

    private func parseLinks(in attributedString: AttributedString) -> [(name: String, url: URL)] {
        attributedString.runs.compactMap { run -> (name: String, url: URL)? in
            guard let link = run.link ?? run.imageURL else {
                return nil
            }
            let name = NSAttributedString(AttributedString(attributedString[run.range])).string
            return (name: name, url: link)
        }
    }
}
