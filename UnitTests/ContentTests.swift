//
//  ContentTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

class ContentTests: XCTestCase {

    func test_keyValue() {
        let data = self.data(for: "KeyValue.json")
        do {
            let keyValue = try JSONDecoder().decode(KeyValue.self, from: data)
            XCTAssertNotNil(keyValue)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test_firstAndEnc() {
        let data = self.data(for: "FirstAndEncrypted.json")
        do {
            let keyVals = try JSONDecoder().decode([KeyValue].self, from: data)
            XCTAssertNotNil(keyVals)
            XCTAssertTrue(keyVals.count == 2)
            XCTAssertNil(keyVals[0].value.previous)
            XCTAssertNotNil(keyVals[1].value.previous)
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_ContentVote() {
        let data = self.data(for: "ContentVote.json")
        do {
            let contentVote = try JSONDecoder().decode(ContentVote.self, from: data)
            XCTAssertTrue(contentVote.type == .vote)
            XCTAssertFalse(contentVote.vote.link.isEmpty)
            XCTAssertTrue(contentVote.vote.value == 1)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test_PrivateVote() {
        let data = self.data(for: "ContentPrivate.json")
        do {
            let contents = try JSONDecoder().decode([Content].self, from: data)
            for (i,c) in contents.enumerated() {
                switch i {
                case 0:
                    XCTAssertTrue(c.type == .vote)
                    XCTAssertFalse((c.vote?.vote.link.isEmpty)!)
                    XCTAssertTrue(c.vote?.vote.value == 1)
                    XCTAssertEqual(c.vote?.recps?.count, 5)
                case 1:
                    XCTAssertTrue(c.type == .post)
                    XCTAssertEqual(c.post?.recps?.count, 3)
                default:
                    XCTFail("unhandled content case \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_KeyValueVote() {
        let data = self.data(for: "KeyValueVote.json")
        do {
            let keyValue = try JSONDecoder().decode(KeyValue.self, from: data)
            XCTAssertTrue(keyValue.value.content.type == .vote)
            guard let vote = keyValue.value.content.vote else { XCTFail(); return }
            XCTAssertFalse(vote.vote.link.isEmpty)
            XCTAssertTrue(vote.vote.value == 1)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test_KeyValueFeed() {
        let data = self.data(for: "Feed_cryptix2.json")
        do {
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
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_contacts() {
        let data = self.data(for: "Contacts.json")
        do {
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
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test_abouts() {
        let data = self.data(for: "Abouts.json")
        do {
            let contents = try JSONDecoder().decode([Content].self, from: data)
            XCTAssertNotNil(contents)
            XCTAssertTrue(contents.count == 6)
            for content in contents {
                XCTAssertTrue(content.type == .about)
                XCTAssertTrue(content.isValid)
                XCTAssertTrue(content.typeString == "about")
                XCTAssertNotNil(content.about)
            }
            // these are about all kinds of things.
            // TODO: group them and make sure the decoding is deep enough
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_invalidVote() {
        let data = self.data(for: "InvalidVoteMissingIdentifier.json")
        do {
            var i = 0
            for content in try JSONDecoder().decode([Content].self, from: data) {
                XCTAssertFalse(content.isValid)
                XCTAssertNotNil(content.contentException)
                i+=1
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_post() {
        let data = self.data(for: "PostBranchField.json")
        do {
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
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_postBranchArray() {
        let data = self.data(for: "PostBranchArray.json")
        do {
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
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test_postMentionsBlob() {
        let data = self.data(for: "PostMentionsBlob.json")
        do {
            let value = try JSONDecoder().decode(Value.self, from: data)
            let content = value.content
            XCTAssertEqual(content.type, .post)
            XCTAssertEqual(content.typeString, "post")
            XCTAssertNil(content.about)
            XCTAssertNil(content.contact)
            XCTAssertNil(content.vote)
            
            XCTAssertNotNil(content.post)
            guard let p = content.post else { return }

            XCTAssertTrue(p.hasBlobs)
            guard let b = p.mentions?.asBlobs().first else { return }
            
            XCTAssertEqual(b.identifier, "&JWofdARjh61uDtdUl5ivwYEPJ4T9TWMyztpgPlgkgek=.sha256")
            XCTAssertEqual(b.name, "1614434_10206454331651096_887999461891506870_o.jpg")
            XCTAssertEqual(b.metadata?.numberOfBytes, 67654)
            XCTAssertEqual(b.metadata?.dimensions?.height, 440)
            XCTAssertEqual(b.metadata?.dimensions?.width, 1024)
            XCTAssertEqual(b.metadata?.mimeType, "image/jpeg")
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_postMentionsWithAndWithoutname() {
        let data = self.data(for: "PostsWithMentions.json")
        do {
            let posts = try JSONDecoder().decode([Post].self, from: data)
            guard posts.count == 2 else { XCTFail(); return }

            for (i,p) in posts.enumerated() {
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
        } catch {
            XCTFail("\(error)")
        }
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
    func test_postWithBlobAltText() {
        /*     a post by cel:  %qBZw41oHFPCmtY6VEY1Qh70zliWnNRliRVskWfJtmd4=.sha256
 containing text in this from ![]($blob "alt text..")
 
 right now turns into:
 
 blobs = 1 value {
 [0] = (identifier = "&amU7IBkAyTIAhsXXWvIGHphMj6niAWWMcvYaMFoAyKw=.sha256 \"We must get back to Oakland at once!\"", name = "we-must-get-back-to-oakland-at-once.jpg")
 }
 */

        let data = self.data(for: "PostWithAltText.json")
        do {
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
        } catch {
            XCTFail("\(error)")
        }
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
        let s = String(data:d, encoding: .utf8)!
        XCTAssertTrue(s.contains("{\"link\":\"#helloWorld\"}"))
    }

    func test_postWithInlineHashtagEncode() {
        let p = Post(
            attributedText: NSAttributedString(string: "test post with hashtags #helloWorld"))
        let d = try! p.encodeToData()
        let s = String(data:d, encoding: .utf8)!
        XCTAssertTrue(s.contains("{\"link\":\"#helloWorld\"}"))
    }
    
    func test_postWithHashtagDecode() {
        let data = self.data(for: "PostWithHashtags.json")
        do {
            let content = try JSONDecoder().decode(Content.self, from: data)
            XCTAssertTrue(content.type == .post)
            XCTAssertTrue(content.isValid)
            guard let post = content.post else { XCTFail(); return }
            guard let tags = post.mentions?.asHashtags() else { XCTFail(); return }
            XCTAssertEqual(tags.count, 2)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    
    func test_ValueTimestamp() {
        let data = self.data(for: "ValueTimestamp.json")
        do {
            let val = try JSONDecoder().decode(Value.self, from: data)
            XCTAssertTrue(val.content.type == .vote)
            XCTAssertEqual(val.timestamp, 1573673656588.0159)
            let kv = KeyValue(key: "%test.msg", value: val, timestamp: 0)
            XCTAssertEqual(kv.userDate, Date(timeIntervalSince1970: 1573673656.5880159))
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_invalidJSON() {
        let data = self.data(for: "Invalid.json")
        do {
            let _ = try JSONDecoder().decode(Content.self, from: data)
            XCTFail("data is not valid JSON")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func test_unsupportedBlob() {
        let data = self.data(for: "UnsupportedBlob.json")
        do {
            let content = try JSONDecoder().decode(Content.self, from: data)
            XCTAssertEqual(content.type, .unsupported)
            XCTAssertEqual(content.typeString, "Invalid JSON")
            XCTAssertNil(content.about)
            XCTAssertNil(content.contact)
            XCTAssertNil(content.post)
            XCTAssertNil(content.vote)
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_unsupportedType() {
        let data = self.data(for: "UnsupportedType.json")
        do {
            let content = try JSONDecoder().decode(Content.self, from: data)
            XCTAssertEqual(content.type, .unsupported)
            XCTAssertNotNil(content.typeException)
            XCTAssertEqual(content.typeString, "garbage")
            XCTAssertNil(content.about)
            XCTAssertNil(content.contact)
            XCTAssertNil(content.post)
            XCTAssertNil(content.vote)
        } catch {
            XCTFail("\(error)")
        }
    }

    /// IMPORTANT!
    /// This test specifically iterates the ContentType enum AND
    /// uses a switch statement.  So, if the enum is changed this
    /// test will break because it is written exhaustively.  This
    /// is intentional.  Do not add a `default` case, add the new
    /// type with an encode test or add to the SHOULD NOTE ENCODE
    /// clause.
    func test_ContentCodable() {

        do {
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
        } catch {
            XCTFail()
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
