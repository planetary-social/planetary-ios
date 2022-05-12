//
//  ContentTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

class ContentTests: XCTestCase {

    func test_keyValue() throws {
        let data = self.data(for: "KeyValue.json")
        let keyValue = try JSONDecoder().decode(KeyValue.self, from: data)
        XCTAssertNotNil(keyValue)
        XCTAssertEqual(keyValue.value.content.type, .post)
        XCTAssertEqual(keyValue.value.content.isValid, true)
    }
    
    func test_firstAndEnc() throws {
        let data = self.data(for: "FirstAndEncrypted.json")
        let keyVals = try JSONDecoder().decode([KeyValue].self, from: data)
        XCTAssertNotNil(keyVals)
        XCTAssertTrue(keyVals.count == 2)
        XCTAssertNil(keyVals[0].value.previous)
        XCTAssertNotNil(keyVals[1].value.previous)
        XCTAssertEqual(keyVals[0].value.content.type, .contact)
        XCTAssertEqual(keyVals[0].value.content.isValid, true)
    }

    func test_ContentVote() throws {
        let data = self.data(for: "ContentVote.json")
        let contentVote = try JSONDecoder().decode(ContentVote.self, from: data)
        XCTAssertTrue(contentVote.type == .vote)
        XCTAssertFalse(contentVote.vote.link.isEmpty)
        XCTAssertTrue(contentVote.vote.value == 1)
    }
    
    func test_PrivateVote() throws {
        let data = self.data(for: "ContentPrivate.json")
        let contents = try JSONDecoder().decode([Content].self, from: data)
        for (i, c) in contents.enumerated() {
            switch i {
            case 0:
                XCTAssertTrue(c.type == .vote)
                XCTAssertFalse((c.vote?.vote.link.isEmpty)!)
                XCTAssertTrue(c.vote?.vote.value == 1)
                XCTAssertEqual(c.vote?.recps?.count, 5)
                XCTAssertEqual(c.isValid, true)
            case 1:
                XCTAssertTrue(c.type == .post)
                XCTAssertEqual(c.post?.recps?.count, 3)
                XCTAssertEqual(c.isValid, true)
            default:
                XCTFail("unhandled content case \(i)")
            }
        }
    }

    func test_KeyValueVote() throws {
        let data = self.data(for: "KeyValueVote.json")
        let keyValue = try JSONDecoder().decode(KeyValue.self, from: data)
        XCTAssertTrue(keyValue.value.content.type == .vote)
        XCTAssertEqual(keyValue.value.content.isValid, true)
        guard let vote = keyValue.value.content.vote else { XCTFail(); return }
        XCTAssertFalse(vote.vote.link.isEmpty)
        XCTAssertTrue(vote.vote.value == 1)
    }
    
    func test_KeyValueFeed() throws {
        let data = self.data(for: "Feed_cryptix2.json")
        let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
        XCTAssertNotNil(msgs)
        XCTAssertEqual(msgs.count, 961)
        for m in msgs {
            XCTAssertNotNil(m.value.content.type)
            if m.value.content.type == .unknown {
                XCTAssertEqual(m.value.content.typeString, "xxx-encrypted",
                "encrypted msg \(m.value.sequence) (\(m.key)) not marked as such")
            }
        }
    }

    func test_contacts() throws {
        let data = self.data(for: "Contacts.json")
        let contacts = try JSONDecoder().decode([Content].self, from: data)
        XCTAssertNotNil(contacts)
        XCTAssertTrue(contacts.count == 4)
        for c in contacts {
            XCTAssertTrue(c.type == .contact)
            XCTAssertTrue(c.isValid)
            XCTAssertTrue(c.typeString == "contact")
            XCTAssertNotNil(c.contact)
            XCTAssertTrue(c.contact?.contact == "@URSb7GMTxPuEygB3956QXsaYELO2rMoSvj0GdVTnrIw=.ed25519")
        }
        XCTAssertTrue((contacts[0].contact?.blocking)!)
        XCTAssertTrue((contacts[1].contact?.blocking)!)
        XCTAssertTrue((contacts[2].contact?.following)!)
        XCTAssertTrue((contacts[3].contact?.following)!)
    }
    
    func test_abouts() throws {
        let data = self.data(for: "Abouts.json")
        let contents = try JSONDecoder().decode([Content].self, from: data)
        XCTAssertNotNil(contents)
        XCTAssertEqual(contents.count, 9)
        for content in contents {
            XCTAssertTrue(content.type == .about)
            XCTAssertTrue(content.isValid)
            XCTAssertTrue(content.typeString == "about")
            XCTAssertNotNil(content.about)
        }
        // these are about all kinds of things.
        // TODO: group them and make sure the decoding is deep enough
    }

    func test_invalidVote() throws {
        let data = self.data(for: "InvalidVoteMissingIdentifier.json")
        var i = 0
        for content in try JSONDecoder().decode([Content].self, from: data) {
            XCTAssertFalse(content.isValid)
            XCTAssertNotNil(content.contentException)
            i += 1
        }
    }

    func test_post() throws {
        let data = self.data(for: "PostBranchField.json")
        let content = try JSONDecoder().decode(Content.self, from: data)
        XCTAssertTrue(content.type == .post)
        XCTAssertTrue(content.isValid)
        guard let post = content.post else { XCTFail(); return }
        XCTAssertNotNil(post.root)
        XCTAssertNotNil(post.branch)
        XCTAssertTrue(post.branch?.count == 1)
        XCTAssertNotNil(post.mentions)
        XCTAssertTrue((post.mentions?.count ?? 0) > 0)
        XCTAssertNil(post.recps)
        XCTAssertNotNil(post.reply)
    }

    func test_postBranchArray() throws {
        let data = self.data(for: "PostBranchArray.json")
        let content = try JSONDecoder().decode(Content.self, from: data)
        XCTAssertTrue(content.type == .post)
        XCTAssertTrue(content.isValid)
        guard let post = content.post else { XCTFail(); return }
        XCTAssertNotNil(post.root)
        XCTAssertNotNil(post.branch)
        XCTAssertTrue(post.branch?.count == 2)
        XCTAssertNotNil(post.mentions)
        XCTAssertTrue((post.mentions?.count ?? 0) > 0)
        XCTAssertNil(post.recps)
        XCTAssertNotNil(post.reply)
    }
    
    func test_postMentionsBlob() throws {
        let data = self.data(for: "PostMentionsBlob.json")
        let value = try JSONDecoder().decode(Value.self, from: data)
        let content = value.content
        XCTAssertEqual(content.type, .post)
        XCTAssertEqual(content.typeString, "post")
        XCTAssertEqual(content.isValid, true)
        XCTAssertNil(content.about)
        XCTAssertNil(content.contact)
        XCTAssertNil(content.vote)
        
        XCTAssertNotNil(content.post)
        guard let p = content.post else { return }

        XCTAssertTrue(p.hasBlobs)
        guard let b = p.mentions?.asBlobs().first else { return }
        
        XCTAssertEqual(b.identifier, "&JWofdARjh61uDtdUl5ivwYEPJ4T9TWMyztpgPlgkgek=.sha256")
        XCTAssertEqual(b.name, "1614434_10206454331651096_887999461891506870_o.jpg")
        XCTAssertEqual(b.metadata?.numberOfBytes, 67_654)
        XCTAssertEqual(b.metadata?.dimensions?.height, 440)
        XCTAssertEqual(b.metadata?.dimensions?.width, 1_024)
        XCTAssertEqual(b.metadata?.mimeType, "image/jpeg")
    }

    func test_postMentionsWithAndWithoutname() throws {
        let data = self.data(for: "PostsWithMentions.json")
        let posts = try JSONDecoder().decode([Post].self, from: data)
        guard posts.count == 2 else { XCTFail(); return }

        for (i, p) in posts.enumerated() {
            guard let m = p.mentions else { XCTFail(); return }

            guard m.count == 1 else { XCTFail(); return }

            switch i {
            case 0:
                XCTAssertEqual("some1", m[0].name)
            case 1:
                XCTAssertNil(m[0].name)
            default: XCTFail("unhandled case: \(i)")
            }
        }
    }
    
    func testPubParsing() throws {
        let data = self.data(for: "Pub.json")
        let msg = try JSONDecoder().decode(KeyValue.self, from: data)
        XCTAssertEqual(msg.value.content.type, .pub)
        XCTAssertEqual(msg.value.content.isValid, true)
        XCTAssertEqual(msg.value.content.contentException, nil)
    }

    // TODO need to confirm string content to ensure everything was captured
    // prefix ![
    // suffix =.sha256)
    func test_postMarkdownSingleInlineBlob() {

        let markdown = "![Screen Shot 2019-07-06 at 12.16.32 PM.png](&0YUaViS1l5tbgDxXGULWmb6CO+vTMB7JbFAfNT9r5vw=.sha256)"

        let stringsAndRanges = markdown.blobSubstringsAndRanges()
        XCTAssertTrue(stringsAndRanges.count == 1)

        let blobsAndRanges = markdown.blobsAndRanges()
        XCTAssertTrue(blobsAndRanges.count == 1)

        let blobs = markdown.blobs()
        XCTAssertTrue(blobs.count == 1)
    }

    // TODO https://app.asana.com/0/914798787098068/1154369858862963/f
    // return more than the first match
    func test_postMarkdownMultipleInlineBlobs() {

        let markdown = " * Tap your profile photo in the upper left of the Home screen, and select a photo from your library to use as a profile image\n\n![Screen Shot 2019-07-06 at 12.16.32 PM.png](&0YUaViS1l5tbgDxXGULWmb6CO+vTMB7JbFAfNT9r5vw=.sha256)\n![Screen Shot 2019-07-06 at 12.16.44 PM.png](&c8Rdu7eoBLsoGg3EPB7VXY4mhC1dw9/rLkgIsJy7XWc=.sha256)\n\n### Coming Soon\n*"
        let stringsAndRanges = markdown.blobSubstringsAndRanges()
        XCTAssertTrue(stringsAndRanges.count == 2)

        let blobsAndRanges = markdown.blobsAndRanges()
        XCTAssertTrue(blobsAndRanges.count == 2)

        let blobs = markdown.blobs()
        XCTAssertTrue(blobs.count == 2)
    }
    
    // TODO https://app.asana.com/0/914798787098068/1154472587426507/f
    // TODO improve String.blobSubstringsAndRanges() to support alt text
    func test_postWithBlobAltText() throws {
        /*     a post by cel:  %qBZw41oHFPCmtY6VEY1Qh70zliWnNRliRVskWfJtmd4=.sha256
 containing text in this from ![]($blob "alt text..")
 
 right now turns into:
 
 blobs = 1 value {
 [0] = (identifier = "&amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw=.sha256 \"We must get back to Oakland at once!\"", name = "we-must-get-back-to-oakland-at-once.jpg")
 }
 */

        let data = self.data(for: "PostWithAltText.json")
        let kv = try JSONDecoder().decode(KeyValue.self, from: data)
        let content = kv.value.content
        XCTAssertEqual(content.type, .post)
        XCTAssertEqual(content.typeString, "post")
        XCTAssertNil(content.about)
        XCTAssertNil(content.contact)
        XCTAssertNil(content.vote)
        
        XCTAssertNotNil(content.post)
        guard let p = content.post else { return }
        
        // fill blobs
        //            let _ = p.attributedString
        
        XCTAssertTrue(p.hasBlobs)
        guard let b = p.mentions?.asBlobs().first else { return }
        
        XCTAssertEqual(b.identifier, "&amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw=.sha256")
        XCTAssertEqual(b.name, "we-must-get-back-to-oakland-at-once.jpg")
        
        // one could argue that the alt text is the better inline description but one step at a time?
        //            XCTAssertEqual(content.post!.blobs!.first!.name, "We must get back to Oakland at once!")
    }

    func test_postWithHashtagEncode() {
        let p = Post(
            blobs: nil,
            branches: nil,
            hashtags: [Hashtag(name: "helloWorld")],
            mentions: nil,
            root: nil,
            text: "test post with hashtags")
        let d = try! p.encodeToData()
        let s = String(data: d, encoding: .utf8)!
        XCTAssertTrue(s.contains("{\"link\":\"#helloWorld\"}"))
    }

    func test_postWithInlineHashtagEncode() {
        let p = Post(
            attributedText: NSAttributedString(string: "test post with hashtags #helloWorld"))
        let d = try! p.encodeToData()
        let s = String(data: d, encoding: .utf8)!
        XCTAssertTrue(s.contains("{\"link\":\"#helloWorld\"}"))
    }
    
    func test_postWithHashtagDecode() throws {
        let data = self.data(for: "PostWithHashtags.json")
        let content = try JSONDecoder().decode(Content.self, from: data)
        XCTAssertTrue(content.type == .post)
        XCTAssertTrue(content.isValid)
        guard let post = content.post else { XCTFail(); return }
        guard let tags = post.mentions?.asHashtags() else { XCTFail(); return }
        XCTAssertEqual(tags.count, 2)
    }
    
    func test_ValueTimestamp() throws {
        let data = self.data(for: "ValueTimestamp.json")
        let val = try JSONDecoder().decode(Value.self, from: data)
        XCTAssertTrue(val.content.type == .vote)
        XCTAssertEqual(val.timestamp, 1_573_673_656_588.015_9)
        let kv = KeyValue(key: "%test.msg", value: val, timestamp: 0)
        XCTAssertEqual(kv.userDate, Date(timeIntervalSince1970: 1_573_673_656.588_015_9))
    }

    func test_invalidJSON() {
        let data = self.data(for: "Invalid.json")
        XCTAssertThrowsError(try JSONDecoder().decode(Content.self, from: data))
    }

    func test_unsupportedBlob() throws {
        let data = self.data(for: "UnsupportedBlob.json")
        let content = try JSONDecoder().decode(Content.self, from: data)
        XCTAssertEqual(content.type, .unsupported)
        XCTAssertEqual(content.isValid, false)
        XCTAssertEqual(content.typeString, "Invalid JSON")
        XCTAssertNil(content.about)
        XCTAssertNil(content.contact)
        XCTAssertNil(content.post)
        XCTAssertNil(content.vote)
    }

    func test_unsupportedType() throws {
        let data = self.data(for: "UnsupportedType.json")
        let content = try JSONDecoder().decode(Content.self, from: data)
        XCTAssertEqual(content.type, .unsupported)
        XCTAssertEqual(content.isValid, false)
        XCTAssertNotNil(content.typeException)
        XCTAssertEqual(content.typeString, "garbage")
        XCTAssertNil(content.about)
        XCTAssertNil(content.contact)
        XCTAssertNil(content.post)
        XCTAssertNil(content.vote)
    }

    /// IMPORTANT!
    /// This test specifically iterates the ContentType enum AND
    /// uses a switch statement.  So, if the enum is changed this
    /// test will break because it is written exhaustively.  This
    /// is intentional.  Do not add a `default` case, add the new
    /// type with an encode test or add to the SHOULD NOTE ENCODE
    /// clause.
    func test_ContentCodable() throws {
        
        try ContentType.allCases.forEach {
            switch $0 {
                
            case .about:
                let data = try About(about: .testIdentity, name: "test").encodeToData()
                let content = try? JSONDecoder().decode(Content.self, from: data)
                XCTAssertTrue(content?.assertValid() ?? false)
                break
                
            case .contact:
                let data = try Contact(contact: .testIdentity, blocking: true).encodeToData()
                let content = try? JSONDecoder().decode(Content.self, from: data)
                XCTAssertTrue(content?.assertValid() ?? false)
                break
                
            case .dropContentRequest:
                let fakeHash = "%ifDrcOptVFcnYmXggTDnhIsux+J9VaiV0Tlgsh/My24=.ggfeed-v1"
                let data = try DropContentRequest(sequence: 1, hash: fakeHash).encodeToData()
                let content = try? JSONDecoder().decode(DropContentRequest.self, from: data)
                //                        XCTAssertTrue(content?.assertValid() ?? false)
                XCTAssertNotNil(content)
                XCTAssertEqual(content?.sequence, 1)
                XCTAssertEqual(content?.hash, fakeHash)
                break
                
            case .post:
                let data = try Post(text: "this is a test").encodeToData()
                let content = try? JSONDecoder().decode(Content.self, from: data)
                XCTAssertTrue(content?.assertValid() ?? false)
                break
                
            case .vote:
                let data = try ContentVote(link: .testLink, value: 1).encodeToData()
                let content = try? JSONDecoder().decode(Content.self, from: data)
                XCTAssertTrue(content?.assertValid() ?? false)
                
                // models that SHOULD NOT be encoded
            case .pub, .address, .unknown, .unsupported: break
            }
        }
    }
}

// Convenience identity for testing only
extension Identity {
    static let testIdentity = "@URSb7GMTxPuEygB3956QXsaYELO2rMoSvj0GdVTnrIw=.ed25519"
}

// Convenience link identifier for testing only
extension LinkIdentifier {
    static let testLink = "%ifDrcOptVFcnYmXggTDnhIsux+J9VaiV0Tlgsh/My24=.sha256"
}

fileprivate extension Content {

    /// Similar to `isValid` but does a deeper validation that any
    /// inner model instance actually matches the content type.
    /// This is a little brittle, like `decodeByContentType()` but
    /// I can't quite think of a more automatic, type-safe way to
    /// check this at the moment.  Ideally the inner model properties
    /// should be read only which would negate the need for this.
    func assertValid() -> Bool {
        switch self.type {
            case .about: return self.about != nil
            case .address: return self.address != nil
            case .contact: return self.contact != nil
            case .dropContentRequest: return self.dropContentRequest != nil
            case .pub: return self.pub != nil
            case .post: return self.post != nil
            case .vote: return self.vote != nil
            case .unsupported: return false
            case .unknown: return false
        }
    }
}
