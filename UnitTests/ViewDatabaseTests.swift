import XCTest
import SQLite

class ViewDatabaseTests: XCTestCase {

    var tmpURL = URL(string: "unset")!
    var vdb = ViewDatabase()
    let expMsgCount = 81
    let fixture = DatabaseFixture.exampleFeed
    var testFeeds: [Identity] { fixture.identities }
    var currentUser: Identity { fixture.identities[4] }

    override func setUp() async throws {
        try await super.setUp()
        let data = self.data(for: fixture.fileName)

        do {
            await vdb.close()
            
            // get random location for the new db
            self.tmpURL = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), "viewDBtest-feedFill2"])!

            do {
                try FileManager.default.removeItem(at: self.tmpURL)
            } catch {
                // ignore - most likely not exists
            }
           
            try FileManager.default.createDirectory(at: self.tmpURL, withIntermediateDirectories: true)
            
            // open DB
            let  damnPath = self.tmpURL.absoluteString.replacingOccurrences(of: "file://", with: "")
            try self.vdb.open(path: damnPath, user: currentUser, maxAge: -60 * 60 * 24 * 30 * 48) // 48 month (so roughtly until 2023)
            
            // get test messages from JSON
            let msgs = try JSONDecoder().decode([Message].self, from: data)
            XCTAssertNotNil(msgs)
            // +1 to fake-cause the duplication bug
            XCTAssertEqual(msgs.count, expMsgCount + 1)
            
            // put them all in
            try vdb.fillMessages(msgs: msgs)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        await vdb.close()
    }

    func test01_stats() {
        do {
            // find them all
            let stats = try self.vdb.stats()
            XCTAssertEqual(stats[.messages], expMsgCount - 8) // 8 tag messages from old test data (TODO better test data creation)
            XCTAssertEqual(stats[.authors], 6)
            XCTAssertEqual(stats[.abouts], 6)
            XCTAssertEqual(stats[.abouts], stats[.authors]) // authors with missing abouts will not be shown
            XCTAssertEqual(stats[.contacts], 10)
            XCTAssertEqual(stats[.posts], 26)
            XCTAssertEqual(stats[.votes], 8)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test10_names() {
        do {
            for (i, f) in testFeeds.enumerated() {
                if let name = try self.vdb.getName(feed: f) {
                    switch i {
                    case 0:
                        XCTAssertEqual("userOne", name)
                    case 1:
                        XCTAssertEqual("userTwo", name)
                    case 2:
                        XCTAssertEqual("realUserThree", name)
                    case 3:
                        XCTAssertEqual("userFour", name)
                    case 4:
                        XCTAssertEqual("privateUser", name)
                    default:
                        XCTFail("unhandled feed: \(i)")
                    }
                } else {
                    XCTFail("no name for \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test11_images() {
        do {
            for (i, f) in testFeeds.enumerated() {
                if let about = try self.vdb.getAbout(for: f) {
                    switch i {
                    case 0:
                        XCTAssertNil(about.description)
                        XCTAssertNil(about.image)
                    case 1:
                        XCTAssertNil(about.description)
                        XCTAssertNil(about.image)
                    case 2:
                        XCTAssertNil(about.description)
                        XCTAssertEqual(about.image?.link, "&RgdcBBv4aV9qMJO7yLN0kxOk1cnbXaGd/m0abI123d0=.sha256")
                    case 3:
                        XCTAssertNil(about.description)
                        XCTAssertNil(about.image)
                    case 4:
                        XCTAssertNil(about.description)
                        XCTAssertNil(about.image)
                    default:
                        XCTFail("unhandled feed: \(i)")
                    }
                } else {
                    XCTFail("no name for \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test20_follows() {
        do {
            for (i, f) in testFeeds.enumerated() {
                let follows: [Identity] = try self.vdb.getFollows(feed: f)
                
                switch i {
                case 0:
                    XCTAssertEqual(follows.count, 1)
                    XCTAssertEqual(follows[0], testFeeds[1])
                case 1:
                    XCTAssertEqual(follows.count, 3)
                    XCTAssertTrue(follows.contains(testFeeds[0]))
                    XCTAssertTrue(follows.contains(testFeeds[3]))
                    XCTAssertTrue(follows.contains(testFeeds[4]))
                case 2:
                    XCTAssertEqual(follows.count, 1)
                    XCTAssertEqual(follows[0], testFeeds[1])
                case 3:
                    XCTAssertEqual(follows.count, 1)
                    XCTAssertEqual(follows[0], testFeeds[1])
                case 4:
                    XCTAssertEqual(follows.count, 2)
                    XCTAssertTrue(follows.contains(testFeeds[0]))
                    XCTAssertTrue(follows.contains(testFeeds[2]))
                default:
                    XCTFail("unhandled feed: \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test21_followedBy() {
        do {
            for (i, f) in testFeeds.enumerated() {
                let follows: [Identity] = try self.vdb.followedBy(feed: f)
                
                switch i {
                case 0:
                    XCTAssertEqual(follows.count, 2)
                    XCTAssertTrue(follows.contains(testFeeds[4]))
                    XCTAssertTrue(follows.contains(testFeeds[1]))
                case 1:
                    XCTAssertEqual(follows.count, 3)
                    XCTAssertTrue(follows.contains(testFeeds[0]))
                    XCTAssertTrue(follows.contains(testFeeds[2]))
                    XCTAssertTrue(follows.contains(testFeeds[3]))
                case 2:
                    XCTAssertEqual(follows.count, 1)
                    XCTAssertEqual(follows[0], testFeeds[4])
                case 3:
                    XCTAssertEqual(follows.count, 1)
                    XCTAssertEqual(follows[0], testFeeds[1])
                case 4:
                    XCTAssertEqual(follows.count, 1)
                    XCTAssertEqual(follows[0], testFeeds[1])
                default:
                    XCTFail("unhandled feed: \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func test220_blocks() {
        do {
            for (i, f) in testFeeds.enumerated() {
                let blocks = try self.vdb.getBlocks(feed: f)
                
                switch i {
                case 0:
                    XCTAssertEqual(blocks.count, 1)
                    XCTAssertEqual(blocks[0], testFeeds[2])
                case 1:
                    XCTAssertEqual(blocks.count, 0)
                case 2:
                    XCTAssertEqual(blocks.count, 0)
                case 3:
                    XCTAssertEqual(blocks.count, 0)
                case 4:
                    XCTAssertEqual(blocks.count, 0)
                default:
                    XCTFail("unhandled feed: \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test231_blockedBy() {
        do {
            for (i, f) in testFeeds.enumerated() {
                let blocks = try self.vdb.blockedBy(feed: f)
                switch i {
                case 0:
                    XCTAssertEqual(blocks.count, 0)
                case 1:
                    XCTAssertEqual(blocks.count, 0)
                case 2:
                    XCTAssertEqual(blocks.count, 1)
                    XCTAssertEqual(blocks[0], testFeeds[0])
                case 3:
                    XCTAssertEqual(blocks.count, 0)
                case 4:
                    XCTAssertEqual(blocks.count, 0)
                default:
                    XCTFail("unhandled feed: \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test23_friends() {
        do {
            for (i, f) in testFeeds.enumerated() {
                let ret = try self.vdb.getBidirectionalFollows(feed: f)
                switch i {
                case 0:
                    XCTAssertEqual(ret.count, 1)
                    XCTAssertEqual(ret[0], testFeeds[1])
                case 1:
                    XCTAssertEqual(ret.count, 2)
                    XCTAssertEqual(ret[0], testFeeds[0])
                    XCTAssertEqual(ret[1], testFeeds[3])
                case 2:
                    XCTAssertEqual(ret.count, 0)
                case 3:
                    XCTAssertEqual(ret.count, 1)
                    XCTAssertEqual(ret[0], testFeeds[1])
                case 4:
                    XCTAssertEqual(ret.count, 0)
                default:
                    XCTFail("unhandled feed: \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func test30_replies() {
        do {
            // TODO: verify ordering
            let replies = try self.vdb.getRepliesTo(thread: "%fmm1SMij8QGyT1fyvBX686FdmVyetkDIpr+nMoURvWs=.sha256")
            XCTAssertEqual(replies.count, 7)
            for (i, kv) in replies.enumerated() {
                XCTAssertNil(kv.content.typeException, "type exception on reply \(i)")
                
                switch i {
                case 0:
                    XCTAssertEqual(kv.key, "%A779Qiywc+HJoMT1xfmuqGymyS9pnjNal+WfHBgk2GQ=.sha256")
                    XCTAssertEqual(kv.author, testFeeds[0])
                    XCTAssertEqual(kv.content.type, .post)
                    XCTAssertEqual(kv.content.post?.text, "here is a reply")
                case 1:
                    XCTAssertEqual(kv.key, "%2q0+HuVVun2LWCb/uQVQThFAA65VHxrzDIwRYuljoSY=.sha256")
                    XCTAssertEqual(kv.author, testFeeds[1])
                    XCTAssertEqual(kv.content.type, .post)
                    XCTAssertEqual(kv.content.post?.text, "hello you!")
                case 2:
                    XCTAssertEqual(kv.key, "%he1uimaQ3D7i2dIEsGkaNlCk31QfjV6C0FBIU5iBCUY=.sha256")
                    XCTAssertEqual(kv.author, "@TiCSZy2ICusS4RbL3H0I7tyrDFkucAVqTp6cjw2PETI=.ed25519")
                    XCTAssertEqual(kv.content.type, .post)
                    XCTAssertEqual(kv.content.post?.text, "nice meeting you all!")
                case 3:
                    XCTAssertEqual(kv.key, "%ytHCZiyd7MJ6F4vHjQwliGZx/vnm98URcF390KmQluE=.sha256")
                    XCTAssertEqual(kv.author, "@gIBNiimNRlGPP0Ob2jV6cpiVukfbHoIvGlkYIidHpKY=.ed25519")
                    XCTAssertEqual(kv.content.type, .post)
                    XCTAssertEqual(kv.content.post?.text, "[@realUserThree](@TiCSZy2ICusS4RbL3H0I7tyrDFkucAVqTp6cjw2PETI=.ed25519) who are you?!")
                case 4:
                    XCTAssertEqual(kv.key, "%M44KTcFtA0HuBAMqnZmLHgmJDj/XnE5a3KdgCosfnSU=.sha256")
                    XCTAssertEqual(kv.author, testFeeds[3])
                    XCTAssertEqual(kv.content.type, .post)
                    XCTAssertEqual(kv.content.post?.text, "hello people!")
                case 5:
                    XCTAssertEqual(kv.key, "%YGZ8L7iAv3b50k3/Nks7Jm//2v6t9Jd/di1l6q/eIe8=.sha256")
                    XCTAssertEqual(kv.author, testFeeds[1])
                    XCTAssertEqual(kv.content.type, .post)
                    XCTAssertEqual(kv.content.post?.text, "[@userFour](@27PkouhQuhr9Ffn+rgSnN0zabcfoE31qD3ZMkCs3c+0=.ed25519) hey you!\n\n[@userOne](@gIBNiimNRlGPP0Ob2jV6cpiVukfbHoIvGlkYIidHpKY=.ed25519) i don\'t know either..")
                    // TODO: decode & check mentions
                case 6:
                    XCTAssertEqual(kv.key, "%ruVFSar2PMCK1WZdz0AL7JIOgxjbFuwcHL8zWrqw9Ig=.sha256")
                    XCTAssertEqual(kv.author, DatabaseFixture.exampleFeed.secret.identity)
                    XCTAssertEqual(kv.content.type, .post)
                    XCTAssertEqual(kv.content.post?.text, "new reply to old thread.")
                default:
                    XCTFail("unhandled reply: \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test40_feed_counts() {
        do {
            for (i, tf) in testFeeds.enumerated() {
                let replies = try self.vdb.feed(for: tf)
                switch i {
                case 0:
                    XCTAssertEqual(replies.count, 1)
                case 1:
                    XCTAssertEqual(replies.count, 5)
                case 2:
                    XCTAssertEqual(replies.count, 4)
                case 3:
                    XCTAssertEqual(replies.count, 0)
                case 4:
                    XCTAssertEqual(replies.count, 3)
                default:
                    XCTFail("unhandled reply: \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test41_feed() {
        do {
            let replies = try self.vdb.feed(for: currentUser)
            for (i, kv) in replies.enumerated() {
                XCTAssertNil(kv.content.typeException, "type exception on reply \(i)")
                XCTAssertEqual(kv.author, currentUser)
                XCTAssertEqual(kv.content.type, .post)
                switch i {
                case 0:
                    XCTAssertEqual(kv.key, "%mGqnXFLLANmscYjQCafniOTbnTC4RoRP8lZNlswaCdc=.sha256")

                case 1:
                    XCTAssertEqual(kv.key, "%KfVCyfVWiFAS75sSura943LTN/ylGvYBfBtfzZkRO28=.sha256")
                case 2:
                    XCTAssertEqual(kv.key, "%7TK9l4TT0yc8PCarcnLZEuxb0FtShl2M8vvbCSjceXY=.sha256")

                default:
                    XCTFail("unhandled reply: \(i)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func test50_mentions_names() {
        let k = "%W0qeHpJqbvq3RsAXkAPp4G6GMomOWs+OoQJLEEK+dUE=.sha256"
        do {
            let post = try self.vdb.post(with: k)
            XCTAssertEqual(post.key, k)
            XCTAssertEqual(post.content.post?.mentions?.count, 4)
            if let m = post.content.post?.mentions {
                XCTAssertEqual(m[0].name, "userOne")
                XCTAssertEqual(m[1].name, "userTwo")
                XCTAssertEqual(m[2].name, "realUserThree")
                XCTAssertEqual(m[3].name, "userFour")
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test51_mentions_images() {
        let k = "%2AyeVqqLtRZf8KuJh2yz3fOh1zpfBYWqFnw2ZlNPs3A=.sha256"
        do {
            let post = try self.vdb.post(with: k)
            XCTAssertEqual(post.key, k)
            XCTAssertEqual(post.content.post?.mentions?.count, 1)
            if let m = post.content.post?.mentions {
                XCTAssertEqual(m[0].link, "&iPoiwMJzpTfYSyoyEVpZabvXFUXqC9UHlC1Sm/F9vG0=.sha256")
                XCTAssertEqual(m[0].name, "exp.jpg")
                // TODO: fille type
                // TODO: size
            }
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test61_has_blobs() {
        let k = "%jxj5ilzRk1SKTLp11BVGsJvcmgf+ArwxnKNVb6KWYs4=.sha256"
        do {
            let post = try self.vdb.post(with: k)
            XCTAssertEqual(post.key, k)
            guard let p = post.content.post else {
                XCTFail("not a post")
                return
            }
            XCTAssertEqual(p.text, "I swear this one will work...")
            XCTAssertEqual(p.mentions?.asBlobs().count, 3)
            guard let b = p.mentions?.asBlobs() else {
                XCTFail("not a blob")
                return
            }
            guard b.count == 3 else {
                XCTFail("blob count != 1, got \(b.count)")
                return
            }
            XCTAssertEqual(b[0].identifier, "&2eD1jIEPz3NC1kD3VoKHbJBt1mkheyA32BjI1IO69CQ=.sha256")
            XCTAssertEqual(b[0].name, "blob")
            XCTAssertEqual(b[0].metadata?.dimensions?.width, 100)
            XCTAssertEqual(b[0].metadata?.dimensions?.height, 100)
            XCTAssertEqual(b[0].metadata?.numberOfBytes, 143_333)
            XCTAssertEqual(b[0].metadata?.mimeType, "image/jpeg")
        } catch {
            XCTFail("\(error)")
        }
    }

    func test61_channel_messages() {
        do {
            let lMsgs = try self.vdb.messagesForHashtag(name: "hashtag")
            XCTAssertEqual(lMsgs.count, 1)

            let t1msgs = try self.vdb.messagesForHashtag(name: "hello")
            XCTAssertEqual(t1msgs.count, 1)

            let t2msgs = try self.vdb.messagesForHashtag(name: "world")
            XCTAssertEqual(t2msgs.count, 1)
        } catch {
            XCTFail("\(error)")
        }
    }

    func test70_notifications() {
        do {
            let msgs = try self.vdb.mentions()
            XCTAssertEqual(msgs.count, 1)
            if msgs.count < 1 {
                return
            }
            XCTAssertEqual(msgs[0].content.type, .post)
            XCTAssertNotEqual(msgs[0].author, DatabaseFixture.exampleFeed.secret.identity)
            XCTAssertEqual(msgs[0].author, testFeeds[1])
            XCTAssertEqual(msgs[0].content.post?.text, "hey [@privateUser](@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519)! how is it going? (mentions test)")
            XCTAssertEqual(msgs[0].content.post?.mentions?.count, 1)
        } catch {
            XCTFail("\(error)")
        }
    }

    func test71_notifications_follows() {
        do {
            let msgs: [Message] = try self.vdb.followedBy(feed: testFeeds[0])
            XCTAssertEqual(msgs.count, 2)
            if msgs.count != 2 {
                return
            }
            XCTAssertEqual(msgs[0].author, testFeeds[4])
            XCTAssertNotEqual(msgs[0].receivedTimestamp, 0)
            XCTAssertNotEqual(msgs[0].claimedTimestamp, 0)
            XCTAssertEqual(msgs[1].author, testFeeds[1])
            XCTAssertNotEqual(msgs[1].receivedTimestamp, 0)
            XCTAssertNotEqual(msgs[1].claimedTimestamp, 0)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    /// Verifies that `testLargestSeqFromReceiveLog()` excludes posts published by the current user.
    func testLargestSeqFromReceiveLog() throws {
        // Arrange
        let testMessage = MessageFixtures.post(receivedSeq: 1000, author: fixture.owner)
        let largestSeqInDbAtStart: Int64 = 80
        
        // Assert
        XCTAssertEqual(try vdb.largestSeqFromReceiveLog(), largestSeqInDbAtStart)
        
        // Rearrange
        try vdb.fillMessages(msgs: [testMessage])
        
        // Reassert
        XCTAssertEqual(try vdb.largestSeqFromReceiveLog(), testMessage.receivedSeq)
    }
    
    /// Verifies that `largestSeqNotFromPublishedLog()` excludes posts published by the current user.
    func testLargestSeqNotFromPublishedLog() throws {
        // Arrange
        let testMessage = MessageFixtures.post(receivedSeq: 1000, author: fixture.owner)
        let largestSeqInDbAtStart: Int64 = 80

        // Assert
        XCTAssertEqual(try vdb.largestSeqNotFromPublishedLog(), largestSeqInDbAtStart)
        
        // Rearrange
        try vdb.fillMessages(msgs: [testMessage])
        
        // Reassert
        XCTAssertEqual(try vdb.largestSeqNotFromPublishedLog(), largestSeqInDbAtStart)
    }
    
    /// Verifies that `largestSeqFromPublishedLog()` only looks at posts published by the current user.
    func testLargestSeqFromPublishedLog() throws {
        // Arrange
        let testMessage = MessageFixtures.post(receivedSeq: 1000, author: fixture.owner)
        let largestPublishedSeqInDbAtStart: Int64 = 77
        
        // Assert
        XCTAssertEqual(try vdb.largestSeqFromPublishedLog(), largestPublishedSeqInDbAtStart)
        
        // Rearrange
        try vdb.fillMessages(msgs: [testMessage])
        
        // Reassert
        XCTAssertEqual(try vdb.largestSeqFromPublishedLog(), testMessage.receivedSeq)
    }
    
    /// Verifies that `largestSeqFromPublishedLog()` only looks at posts published by the current user.
    func testMessageCount() throws {
        // Arrange
        let sinceTime = Date(timeIntervalSinceNow: -1)
        let postTime = Date().millisecondsSince1970
        let ownerMessage = MessageFixtures.post(
            key: "1",
            receivedTimestamp: postTime,
            receivedSeq: 778,
            author: fixture.owner
        )
        let friendMessageOne = MessageFixtures.post(
            key: "2",
            receivedTimestamp: postTime,
            receivedSeq: 779,
            author: fixture.identities[0]
        )
        let friendMessageTwo = MessageFixtures.post(
            key: "3",
            receivedTimestamp: postTime,
            receivedSeq: 780,
            author: fixture.identities[1]
        )
        
        let startingCount = try vdb.receivedMessageCount(since: sinceTime)
        
        // Rearrange
        try vdb.fillMessages(msgs: [ownerMessage, friendMessageOne, friendMessageTwo])
        
        // Assert
        XCTAssertEqual(try vdb.receivedMessageCount(since: sinceTime), startingCount + 2)
    }
    
    /// Verify that fillMessages deduplicates records.
    func testFillMessagesGivenDuplicateInsert() throws {
        // Arrange
        let messageCount = try vdb.messageCount()
        let testMessage = MessageFixtures.messageWithReceivedSeq
        
        // Act
        try vdb.fillMessages(msgs: [testMessage, testMessage])
        try vdb.fillMessages(msgs: [testMessage])
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), messageCount + 1)
    }
    
    /// Verify that fillMessages does not fill messages older than 6 months.
    func testFillMessagesGivenOldMessage() throws {
        // Arrange
        let messageCount = try vdb.messageCount()
        let oldDate = Date(timeIntervalSince1970: 5)
        let testMessage = MessageFixtures.post(
            timestamp: oldDate.millisecondsSince1970,
            receivedSeq: 800,
            author: IdentityFixture.alice
        )
        
        // Act
        try vdb.fillMessages(msgs: [testMessage])
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), messageCount)
    }
    
    /// Verify that fillMessages fills messages older than 6 months for messages the current user published.
    func testFillMessagesGivenOldMessageFromSelf() throws {
        // Arrange
        let messageCount = try vdb.messageCount()
        let oldDate = Date(timeIntervalSince1970: 1_619_037_184)
        let testMessage = MessageFixtures.post(
            timestamp: oldDate.millisecondsSince1970,
            receivedSeq: 800,
            author: currentUser
        )
        
        // Act
        try vdb.fillMessages(msgs: [testMessage])
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), messageCount + 1)
    }
    
    func testGetAboutForIDGivenUserID() throws {
        // Arrange
        let id = try XCTUnwrap(fixture.identities.first) // userOne
        let expectedAbout = About(about: id, name: "userOne", description: nil, imageLink: nil, publicWebHosting: nil)
        
        // Act
        let about = try vdb.getAbout(for: id)
        
        // Assert
        XCTAssertEqual(about?.identity, expectedAbout.identity)
        XCTAssertEqual(about?.name, expectedAbout.name)
        XCTAssertEqual(about?.description, expectedAbout.description)
        XCTAssertEqual(about?.publicWebHosting, expectedAbout.publicWebHosting)
    }
    
    // MARK: - Bans
    
    /// Verifies that applyBanList deletes banned messages
    func testApplyBanListBansExistingMessage() throws {
        // Arrange
        let startingMessageCount = try vdb.messageCount()
        let bannedAuthor = "@banme"
        let testMessage = MessageFixtures.post(
            receivedSeq: 800,
            author: bannedAuthor
        )
        try vdb.fillMessages(msgs: [testMessage])
        
        // Act
        let (bannedAuthors, unbannedAuthors) = try vdb.applyBanList([testMessage.key.sha256hash])
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), startingMessageCount)
        XCTAssertEqual(bannedAuthors, [])
        XCTAssertEqual(unbannedAuthors, [])
        XCTAssertThrowsError(try vdb.post(with: testMessage.key))
    }
    
    /// Verifies that applyBanList deletes all messages from a banned author and marks the author as banned.
    func testApplyBanListBansExistingAuthor() throws {
        // Arrange
        let bannedAuthor = "@banme"
        let startingMessageCount = try vdb.messageCount()
        let testMessage = MessageFixtures.post(
            receivedSeq: 800,
            author: bannedAuthor
        )
        try vdb.fillMessages(msgs: [testMessage])
        
        // Act
        let (bannedAuthors, unbannedAuthors) = try vdb.applyBanList([bannedAuthor.sha256hash])
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), startingMessageCount)
        XCTAssertEqual(bannedAuthors, [bannedAuthor])
        XCTAssertEqual(unbannedAuthors, [])
        XCTAssertThrowsError(try vdb.post(with: testMessage.key))
    }
    
    /// Verifies that fillMessages will not insert messages that have been banned.
    func testFillBannedMessage() throws {
        // Arrange
        let bannedAuthor = "@banme"
        let startingMessageCount = try vdb.messageCount()
        let testMessage = MessageFixtures.post(
            receivedSeq: 800,
            author: bannedAuthor
        )
        
        // Act
        let (bannedAuthors, unbannedAuthors) = try vdb.applyBanList([testMessage.key.sha256hash])
        try vdb.fillMessages(msgs: [testMessage])
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), startingMessageCount)
        XCTAssertEqual(bannedAuthors, [])
        XCTAssertEqual(unbannedAuthors, [])
        XCTAssertThrowsError(try vdb.post(with: testMessage.key))
    }
    
    /// Verifies that fillMessages will not insert messages from an author that has been banned.
    func testFillBannedAuthor() throws {
        // Arrange
        let startingMessageCount = try vdb.messageCount()
        let bannedAuthor = "@banme"
        let testMessage = MessageFixtures.post(
            receivedSeq: 800,
            author: bannedAuthor
        )
        
        // Act
        let (bannedAuthors, unbannedAuthors) = try vdb.applyBanList([bannedAuthor.sha256hash])
        try vdb.fillMessages(msgs: [testMessage])
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), startingMessageCount)
        XCTAssertEqual(bannedAuthors, [])
        XCTAssertEqual(unbannedAuthors, [])
        XCTAssertThrowsError(try vdb.post(with: testMessage.key))
        XCTAssertNotNil(try vdb.authorID(of: bannedAuthor))
    }
    
    func testUnbanAuthor() throws {
        // Arrange
        let startingMessageCount = try vdb.messageCount()
        let bannedAuthor = "@banme"
        let testMessage = MessageFixtures.post(
            receivedSeq: 800,
            author: bannedAuthor
        )
        
        // Start out with the author banned
        try vdb.fillMessages(msgs: [testMessage])
        _ = try vdb.applyBanList([bannedAuthor.sha256hash])

        // Act
        // unban
        _ = try vdb.applyBanList([])
        // Simulate-re-replication
        try vdb.fillMessages(msgs: [testMessage])
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), startingMessageCount + 1)
        XCTAssertNotNil(try vdb.post(with: testMessage.key))
        XCTAssertNotNil(try vdb.authorID(of: bannedAuthor))
    }
    
    // MARK: Room Alias Announcements
    
    func testFillRoomAliasAnnouncementGivenUnknownRoom() throws {
        // Arrange
        let startingMessageCount = try vdb.messageCount()
        
        let data = self.data(for: "RoomAliasAnnouncement_registered.json")
        let msgs = try JSONDecoder().decode(Message.self, from: data)
        let roomAliasAnnouncement = try XCTUnwrap(msgs.content.roomAliasAnnouncement)
        
        // Act
        try vdb.fillMessages(msgs: [msgs])
        let roomAlias = try XCTUnwrap(vdb.getRegisteredAliasesByUser(user: currentUser).first)
        
        // Assert
        XCTAssertEqual(try vdb.messageCount(), startingMessageCount + 1)
        XCTAssertEqual(roomAlias.aliasURL.absoluteString, "https://matt.hermies.club")
        XCTAssertEqual(roomAlias.id, 1)
        XCTAssertEqual(roomAlias.roomID, nil)
        XCTAssertEqual(roomAlias.authorID, 1)
        XCTAssertEqual(roomAliasAnnouncement.action, RoomAliasAnnouncement.RoomAliasActionType.registered)
        XCTAssertEqual(roomAliasAnnouncement.alias, "matt")
        XCTAssertEqual(roomAliasAnnouncement.aliasURL, "https://matt.hermies.club")
    }
    
    func testFillRoomAliasAnnouncementGivenKnownRoom() throws {
        // Arrange
        let colPubKey = Expression<String>("pub_key")
        let colHost = Expression<String>("host")
        let colPort = Expression<String>("port")
        let colID = Expression<Int64>("id")
        let rooms = Table(ViewDatabaseTableNames.rooms.rawValue)
        let startingMessageCount = try vdb.messageCount()
        
        // Act
        let db = try vdb.checkoutConnection()
        try db.run(
            rooms.insert(
                colID <- 1,
                colHost <- "matt.hermies.club",
                colPort <- "8008",
                colPubKey <- "@uMYDVPuEKftL4SzpRGVyQxLdyPkOiX7njit7+qT/7IQ=.ed25519"
            )
        )
        
        let data = self.data(for: "RoomAliasAnnouncement_registered.json")
        let msgs = try JSONDecoder().decode(Message.self, from: data)
        try vdb.fillMessages(msgs: [msgs])
        
        let roomAlias = try XCTUnwrap(vdb.getRegisteredAliasesByUser(user: currentUser).first)
        let room = try XCTUnwrap(vdb.getJoinedRooms().first)
        
        // Assert
        XCTAssertEqual(try vdb.getJoinedRooms().count, 1)
        XCTAssertEqual(try vdb.messageCount(), startingMessageCount + 1)
        XCTAssertEqual(roomAlias.aliasURL.absoluteString, "https://matt.hermies.club")
        XCTAssertEqual(roomAlias.id, 1)
        XCTAssertEqual(roomAlias.roomID, 1)
        XCTAssertEqual(roomAlias.authorID, 1)
        XCTAssertEqual(room.id, "net:matt.hermies.club:8008~shs:@uMYDVPuEKftL4SzpRGVyQxLdyPkOiX7njit7+qT/7IQ=.ed25519")
        XCTAssertEqual(room.address.host, "matt.hermies.club")
        XCTAssertEqual(room.address.port, 8008)
        XCTAssertEqual(room.address.keyID, "@uMYDVPuEKftL4SzpRGVyQxLdyPkOiX7njit7+qT/7IQ=.ed25519")
    }
    
    func testFillRoomAliasAnnouncementGivenKnownRoomWithRevoke() throws {
        // Arrange
        let colPubKey = Expression<String>("pub_key")
        let colHost = Expression<String>("host")
        let colPort = Expression<String>("port")
        let colID = Expression<Int64>("id")
        let rooms = Table(ViewDatabaseTableNames.rooms.rawValue)
        
        let registeredData = self.data(for: "RoomAliasAnnouncement_registered.json")
        let registeredMsg = try JSONDecoder().decode(Message.self, from: registeredData)
        
        let revokedData = self.data(for: "RoomAliasAnnouncement_revoked.json")
        let revokedMsg = try JSONDecoder().decode(Message.self, from: revokedData)
        
        // Act
        let db = try vdb.checkoutConnection()
        try db.run(
            rooms.insert(
                colID <- 1,
                colHost <- "matt.hermies.club",
                colPort <- "8008",
                colPubKey <- "@uMYDVPuEKftL4SzpRGVyQxLdyPkOiX7njit7+qT/7IQ=.ed25519"
            )
        )
        
        try vdb.fillMessages(msgs: [registeredMsg])
        let roomAliasCountRegistered = try vdb.getRegisteredAliasesByUser(user: currentUser).count
        
        try vdb.fillMessages(msgs: [revokedMsg])
        let roomAliasCountRevoked = try vdb.getRegisteredAliasesByUser(user: currentUser).count
        
        // Assert
        XCTAssertEqual(roomAliasCountRegistered, 1)
        XCTAssertEqual(roomAliasCountRevoked, 0)
    }
}

class ViewDatabasePreloadTest: XCTestCase {
    
    var tmpURL = URL(string: "unset")!
    var vdb = ViewDatabase()
    let preloadExpMsgCount = 5
    let expMsgCount = 81
    let testFeeds = DatabaseFixture.exampleFeed.identities
    var currentUser: Identity { DatabaseFixture.exampleFeed.identities[4] }

    override func setUp() async throws {
        try await super.setUp()
        let preloadData = self.data(for: "Feed_example_preload.json")

        do {
            await self.vdb.close()
            
            // get random location for the new db
            self.tmpURL = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), "viewDBtest-feedFillPreload"])!

            do {
                try FileManager.default.removeItem(at: self.tmpURL)
            } catch {
                // ignore - most likely not exists
            }
           
            try FileManager.default.createDirectory(at: self.tmpURL, withIntermediateDirectories: true)
            
            // open DB
            let  damnPath = self.tmpURL.absoluteString.replacingOccurrences(of: "file://", with: "")
            try self.vdb.open(path: damnPath, user: currentUser, maxAge: -60 * 60 * 24 * 30 * 48) // 48 month (so roughtly until 2023)
            
            // get test messages from JSON
            let msgs = try JSONDecoder().decode([Message].self, from: preloadData)
            XCTAssertNotNil(msgs)
            XCTAssertEqual(msgs.count, preloadExpMsgCount)
            
            // put them all in
            try vdb.fillMessages(msgs: msgs)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        await vdb.close()
    }
    
    func test01_stats() {
        do {
            // find them all
            let stats = try self.vdb.stats()
            XCTAssertEqual(stats[.messages], preloadExpMsgCount)
            XCTAssertEqual(stats[.authors], 3)
            XCTAssertEqual(stats[.abouts], 1)
            XCTAssertEqual(stats[.contacts], 1)
            XCTAssertEqual(stats[.posts], 3)
            XCTAssertEqual(stats[.votes], 0)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test02_load() {
        let data = self.data(for: "Feed_example.json")
        
        do {
            // get test messages from JSON
            let msgs = try JSONDecoder().decode([Message].self, from: data)
            XCTAssertNotNil(msgs)
            // +1 to fake-cause the duplication bug
            XCTAssertEqual(msgs.count, expMsgCount + 1)
            
            // put them all in
            try vdb.fillMessages(msgs: msgs)
            
            // find them all
            let stats = try self.vdb.stats()
            XCTAssertEqual(stats[.messages], expMsgCount - 8) // 8 tag messages from old test data (TODO better test data creation)
            XCTAssertEqual(stats[.authors], 6)
            XCTAssertEqual(stats[.abouts], 6)
            XCTAssertEqual(stats[.abouts], stats[.authors]) // authors with missing abouts will not be shown
            XCTAssertEqual(stats[.contacts], 10)
            XCTAssertEqual(stats[.posts], 26)
            XCTAssertEqual(stats[.votes], 8)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    /// Loads up the preloaded feeds from Preload.bundle and verifies that we can parse them into [Message] and that
    /// they are not empty.
    func testPreloadedFeedsAreParseable() throws {
        let testingBundle = try XCTUnwrap(Bundle(for: type(of: self)))
        let preloadURL = try XCTUnwrap(testingBundle.url(forResource: "Preload", withExtension: "bundle"))
        let preloadBundle = try XCTUnwrap(Bundle(url: preloadURL))
        
        let feedURLs = try XCTUnwrap(preloadBundle.urls(forResourcesWithExtension: "json", subdirectory: "Feeds"))
        let preloadedPubURL = try XCTUnwrap(
            preloadBundle.url(
                forResource: "preloadedPubs",
                withExtension: "json",
                subdirectory: "Pubs"
            )
        )
        
        let allJSONURLs = feedURLs + [preloadedPubURL]
        XCTAssertEqual(allJSONURLs.count, 3)
        try allJSONURLs.forEach { url in
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let msgs = try JSONDecoder().decode([Message].self, from: data)
            XCTAssertEqual(msgs.isEmpty, false)
        }
    }
}
