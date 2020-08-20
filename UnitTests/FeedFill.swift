import XCTest

fileprivate let testKey = Secret(from: """
{
  "curve": "ed25519",
  "public": "MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519",
  "private": "lnozk+qbbO86fv4SkclDqnRH4ilbStDjkr6ZZdVErAgyE6Qw/eMMKC5ttJWXlxWtmI8jdCh0I1eE6ew8DN1LAQ==.ed25519",
  "id": "@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519"
}
""")!

fileprivate let testNetwork = NetworkKey(base64: "5vVhFHLFHeyutypUO952SyFd6jRIVhAyiZV30ftnKSU=")!

fileprivate let testFeeds: [Identity] = [
    "@gIBNiimNRlGPP0Ob2jV6cpiVukfbHoIvGlkYIidHpKY=.ed25519", // one
    "@3cEmxKx9ScNK8Pd1yz0qh5A2URzIbL7+VvpjfETU050=.ed25519", // userTwo
    "@TiCSZy2ICusS4RbL3H0I7tyrDFkucAVqTp6cjw2PETI=.ed25519", // three
    "@27PkouhQuhr9Ffn+rgSnN0zabcfoE31qD3ZMkCs3c+0=.ed25519", // userFour
    "@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519" // privUser
]

class ViewDatabaseBench: XCTestCase {

    func testInsertBig() {
        let data = self.data(for: "Feed_big.json")

        var urls: [URL] = []
        do {
            // get test messages from JSON
            let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
            XCTAssertNotNil(msgs)
            XCTAssertEqual(msgs.count, 2500)
            
            self.measure {
                let vdb = ViewDatabase()
                let tmpURL = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), NSUUID().uuidString])!
                try! FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: true)

                _ = vdb.close() // close init()ed version...
                
                urls += [tmpURL] // don't litter
                
                let  damnPath = tmpURL.absoluteString.replacingOccurrences(of: "file://", with: "")
                try! vdb.open(path: damnPath, user: testKey.identity)
                
                try! vdb.fillMessages(msgs: msgs)
                
                _ = vdb.close()
            }

            print("dropping \(urls.count) runs") // clean up
            for u in urls {
                try FileManager.default.removeItem(at: u)
            }
        } catch {
            XCTFail("\(error)")
        }
    }
}

class ViewDatabaseTest: XCTestCase {
    
    var tmpURL :URL = URL(string: "unset")!
    var vdb = ViewDatabase()
    let expMsgCount = 81

    override func setUp() {
        let data = self.data(for: "Feed_example.json")

        do {
            _ = self.vdb.close()
            
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
            try self.vdb.open(path: damnPath, user: testFeeds[4], maxAge: -60*60*24*30*48) // 48 month (so roughtly until 2023)
            
            // get test messages from JSON
            let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
            XCTAssertNotNil(msgs)
            // +1 to fake-cause the duplication bug
            XCTAssertEqual(msgs.count, expMsgCount+1)
            
            // put them all in
            try vdb.fillMessages(msgs: msgs)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    override func tearDown() {
        vdb.close()
    }

    func test01_stats() {
        do {
            // find them all
            let stats = try self.vdb.stats()
            XCTAssertEqual(stats[.messages], expMsgCount-8) // 8 tag messages from old test data (TODO better test data creation)
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
    
    func test11_images()  {
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
            XCTAssertEqual(replies.count, 13)
            for (i, kv) in replies.enumerated() {
                XCTAssertNil(kv.value.content.typeException, "type exception on reply \(i)")
                
                switch i {
                case 0:
                    XCTAssertEqual(kv.key, "%A779Qiywc+HJoMT1xfmuqGymyS9pnjNal+WfHBgk2GQ=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[0])
                    XCTAssertEqual(kv.value.content.type, .post)
                    XCTAssertEqual(kv.value.content.post?.text, "here is a reply")
                case 1:
                    XCTAssertEqual(kv.key, "%2q0+HuVVun2LWCb/uQVQThFAA65VHxrzDIwRYuljoSY=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[1])
                    XCTAssertEqual(kv.value.content.type, .post)
                    XCTAssertEqual(kv.value.content.post?.text, "hello you!")
                case 2:
                    XCTAssertEqual(kv.key, "%he1uimaQ3D7i2dIEsGkaNlCk31QfjV6C0FBIU5iBCUY=.sha256")
                    XCTAssertEqual(kv.value.author, "@TiCSZy2ICusS4RbL3H0I7tyrDFkucAVqTp6cjw2PETI=.ed25519")
                    XCTAssertEqual(kv.value.content.type, .post)
                    XCTAssertEqual(kv.value.content.post?.text, "nice meeting you all!")
                case 3:
                    XCTAssertEqual(kv.key, "%ytHCZiyd7MJ6F4vHjQwliGZx/vnm98URcF390KmQluE=.sha256")
                    XCTAssertEqual(kv.value.author, "@gIBNiimNRlGPP0Ob2jV6cpiVukfbHoIvGlkYIidHpKY=.ed25519")
                    XCTAssertEqual(kv.value.content.type, .post)
                    XCTAssertEqual(kv.value.content.post?.text, "[@realUserThree](@TiCSZy2ICusS4RbL3H0I7tyrDFkucAVqTp6cjw2PETI=.ed25519) who are you?!")
                case 4:
                    XCTAssertEqual(kv.key, "%l1IwSOOeofqmiOyT84y42Tcn9RJKLeg6zKtVN0v/nIE=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[0])
                    XCTAssertEqual(kv.value.content.type, .vote)
                    XCTAssertEqual(kv.value.content.vote?.vote.value, 1)
                    XCTAssertEqual(kv.value.content.vote?.vote.link, "%2q0+HuVVun2LWCb/uQVQThFAA65VHxrzDIwRYuljoSY=.sha256")
                case 5:
                    XCTAssertEqual(kv.key, "%M44KTcFtA0HuBAMqnZmLHgmJDj/XnE5a3KdgCosfnSU=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[3])
                    XCTAssertEqual(kv.value.content.type, .post)
                    XCTAssertEqual(kv.value.content.post?.text, "hello people!")
                case 6:
                    XCTAssertEqual(kv.key, "%YR/7RhApX0Znb5s4w9B/eDK8fN3/5Jx3z5ih/gOoB6Y=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[3])
                    XCTAssertEqual(kv.value.content.type, .vote)
                    XCTAssertEqual(kv.value.content.vote?.vote.value, 1)
                    XCTAssertEqual(kv.value.content.vote?.vote.link, "%M44KTcFtA0HuBAMqnZmLHgmJDj/XnE5a3KdgCosfnSU=.sha256")
                case 7:
                    XCTAssertEqual(kv.key, "%oQTjGmUQ9S0SLAoKSz+KNL8mRN6aCj2Mrsy0E/nRwOg=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[3])
                    XCTAssertEqual(kv.value.content.type, .vote)
                    XCTAssertEqual(kv.value.content.vote?.vote.value, 0)
                    XCTAssertEqual(kv.value.content.vote?.vote.link, "%M44KTcFtA0HuBAMqnZmLHgmJDj/XnE5a3KdgCosfnSU=.sha256")
                case 8:
                    XCTAssertEqual(kv.key, "%as5O7FtNV1ZfIHnmirVZ2ptHfrBpQWVITtvL5z/CfUc=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[3])
                    XCTAssertEqual(kv.value.content.type, .vote)
                    XCTAssertEqual(kv.value.content.vote?.vote.value, 1)
                    XCTAssertEqual(kv.value.content.vote?.vote.link, "%ytHCZiyd7MJ6F4vHjQwliGZx/vnm98URcF390KmQluE=.sha256")
                case 9:
                    XCTAssertEqual(kv.key, "%CRGKl5idyt7UjFQf7GlgVDd3lcvvCUaWqYs4iip9sjE=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[1])
                    XCTAssertEqual(kv.value.content.type, .vote)
                    XCTAssertEqual(kv.value.content.vote?.vote.value, 1)
                    XCTAssertEqual(kv.value.content.vote?.vote.link, "%M44KTcFtA0HuBAMqnZmLHgmJDj/XnE5a3KdgCosfnSU=.sha256")
                case 10:
                    XCTAssertEqual(kv.key, "%00TehcsrAYe1fHbivR1j0htNj26mzeldSNt7uDO4RZ0=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[1])
                    XCTAssertEqual(kv.value.content.type, .vote)
                    XCTAssertEqual(kv.value.content.vote?.vote.value, 1)
                    XCTAssertEqual(kv.value.content.vote?.vote.link, "%ytHCZiyd7MJ6F4vHjQwliGZx/vnm98URcF390KmQluE=.sha256")
                case 11:
                    XCTAssertEqual(kv.key, "%YGZ8L7iAv3b50k3/Nks7Jm//2v6t9Jd/di1l6q/eIe8=.sha256")
                    XCTAssertEqual(kv.value.author, testFeeds[1])
                    XCTAssertEqual(kv.value.content.type, .post)
                    XCTAssertEqual(kv.value.content.post?.text, "[@userFour](@27PkouhQuhr9Ffn+rgSnN0zabcfoE31qD3ZMkCs3c+0=.ed25519) hey you!\n\n[@userOne](@gIBNiimNRlGPP0Ob2jV6cpiVukfbHoIvGlkYIidHpKY=.ed25519) i don\'t know either..")
                    // TODO: decode & check mentions
                case 12:
                    XCTAssertEqual(kv.key, "%ruVFSar2PMCK1WZdz0AL7JIOgxjbFuwcHL8zWrqw9Ig=.sha256")
                    XCTAssertEqual(kv.value.author, testKey.identity)
                    XCTAssertEqual(kv.value.content.type, .post)
                    XCTAssertEqual(kv.value.content.post?.text, "new reply to old thread.")
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
            let replies = try self.vdb.feed(for: testFeeds[4])
            for (i, kv) in replies.enumerated() {
                XCTAssertNil(kv.value.content.typeException, "type exception on reply \(i)")
                XCTAssertEqual(kv.value.author, testFeeds[4])
                XCTAssertEqual(kv.value.content.type, .post)
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

    func test42_feed_paginated() {
        do {
            let dataProxy = try self.vdb.paginated(feed: testFeeds[4])
            XCTAssertEqual(dataProxy.count, 3)
            for idx in 0...dataProxy.count-1 {
                guard let kv = dataProxy.keyValueBy(index: idx) else {
                    XCTFail("failed to get KV for index \(idx)")
                    continue
                }
                XCTAssertEqual(kv.value.author, testFeeds[4])
                XCTAssertEqual(kv.value.content.type, .post)
                switch idx {
                    case 0:
                        XCTAssertEqual(kv.key, "%mGqnXFLLANmscYjQCafniOTbnTC4RoRP8lZNlswaCdc=.sha256")
                        
                        XCTAssertEqual(kv.value.content.post?.text, "no one would mention themselves.. right [@privateUser](@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519)???")
                    case 1:
                        XCTAssertEqual(kv.key, "%KfVCyfVWiFAS75sSura943LTN/ylGvYBfBtfzZkRO28=.sha256")
                        XCTAssertEqual(kv.value.content.post?.text, "so.. nobody is following me?! feels right.. i can\'t even follow myself most of the time.")
                    case 2:
                        XCTAssertEqual(kv.key, "%7TK9l4TT0yc8PCarcnLZEuxb0FtShl2M8vvbCSjceXY=.sha256")
                        XCTAssertEqual(kv.value.content.post?.text, "so what?")

                    default:
                        XCTFail("unhandled reply: \(idx)")
                }
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func test50_mentions_names() {
        let k = "%W0qeHpJqbvq3RsAXkAPp4G6GMomOWs+OoQJLEEK+dUE=.sha256"
        do {
            let post = try self.vdb.get(key: k)
            XCTAssertEqual(post.key, k)
            XCTAssertEqual(post.value.content.post?.mentions?.count, 4)
            if let m = post.value.content.post?.mentions {
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
            let post = try self.vdb.get(key: k)
            XCTAssertEqual(post.key, k)
            XCTAssertEqual(post.value.content.post?.mentions?.count, 1)
            if let m = post.value.content.post?.mentions {
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
            let post = try self.vdb.get(key: k)
            XCTAssertEqual(post.key, k)
            guard let p = post.value.content.post else {
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
            XCTAssertEqual(b[0].metadata?.numberOfBytes, 143333)
            XCTAssertEqual(b[0].metadata?.mimeType, "image/jpeg")
        } catch {
            XCTFail("\(error)")
        }
    }

    func test60_hashtag_names() {
        do {
            let hashtags = try self.vdb.hashtags()
            XCTAssertEqual(hashtags.count, 3)
            if hashtags.count != 3 {
                return
            }
            // These are shown chronologically
            XCTAssertEqual(hashtags[0].name, "hello")
            XCTAssertEqual(hashtags[1].name, "world")
            XCTAssertEqual(hashtags[2].name, "hashtag")
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
            XCTAssertEqual(msgs[0].value.content.type, .post)
            XCTAssertNotEqual(msgs[0].value.author, testKey.identity)
            XCTAssertEqual(msgs[0].value.author, testFeeds[1])
            XCTAssertEqual(msgs[0].value.content.post?.text, "hey [@privateUser](@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519)! how is it going? (mentions test)")
            XCTAssertEqual(msgs[0].value.content.post?.mentions?.count,1)
        } catch {
            XCTFail("\(error)")
        }
    }

    func test71_notifications_follows() {
        do {
            let msgs: [KeyValue] = try self.vdb.followedBy(feed: testFeeds[0])
            XCTAssertEqual(msgs.count, 2)
            if msgs.count != 2 {
                return
            }
            XCTAssertEqual(msgs[0].value.author, testFeeds[4])
            XCTAssertNotEqual(msgs[0].timestamp, 0)
            XCTAssertNotEqual(msgs[0].value.timestamp, 0)
            XCTAssertEqual(msgs[1].value.author, testFeeds[1])
            XCTAssertNotEqual(msgs[1].timestamp, 0)
            XCTAssertNotEqual(msgs[1].value.timestamp, 0)
        } catch {
            XCTFail("\(error)")
        }
    }
    
}

class ViewDatabasePreloadTest: XCTestCase {
    
    var tmpURL :URL = URL(string: "unset")!
    var vdb = ViewDatabase()
    let preloadExpMsgCount = 5
    let expMsgCount = 81

    override func setUp() {
        let preloadData = self.data(for: "Feed_example_preload.json")

        do {
            _ = self.vdb.close()
            
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
            try self.vdb.open(path: damnPath, user: testFeeds[4], maxAge: -60*60*24*30*48) // 48 month (so roughtly until 2023)
            
            // get test messages from JSON
            let msgs = try JSONDecoder().decode([KeyValue].self, from: preloadData)
            XCTAssertNotNil(msgs)
            XCTAssertEqual(msgs.count, preloadExpMsgCount)
            
            // put them all in
            try vdb.fillMessages(msgs: msgs)
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    override func tearDown() {
        vdb.close()
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
            let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
            XCTAssertNotNil(msgs)
            // +1 to fake-cause the duplication bug
            XCTAssertEqual(msgs.count, expMsgCount+1)
            
            // put them all in
            try vdb.fillMessages(msgs: msgs)
            
            // find them all
            let stats = try self.vdb.stats()
            XCTAssertEqual(stats[.messages], expMsgCount-8) // 8 tag messages from old test data (TODO better test data creation)
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
    
}
