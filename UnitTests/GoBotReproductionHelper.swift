//
//  GoBotAPITests.swift
//
// This test is disabled because it's mostly a template
// It's pretty handy to test some behaviour with an existing repository from an app.
// Need to copy the repo by hand into the simulator, though!!
//
// there must be a better way for this using the xcode resource system
// for the gobot we need to copy a folder
//
//  Created by Henry Bubert on 17.01.20.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

let reproKey = Secret(from: """
{
  "curve": "ed25519",
  "public": "MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519",
  "private": "lnozk+qbbO86fv4SkclDqnRH4ilbStDjkr6ZZdVErAgyE6Qw/eMMKC5ttJWXlxWtmI8jdCh0I1eE6ew8DN1LAQ==.ed25519",
  "id": "@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519"
}
""")!

let reproNetwork = Environment.Networks.test.key
let reproHMAC = Environment.Networks.test.hmac
let reproConfiguration = { () -> AppConfiguration in
    let config = AppConfiguration(with: reproKey)
    config.network = reproNetwork
    config.hmacKey = reproHMAC
    return config
}()

import XCTest

class API_GoBot: XCTestCase {
    
    static var bot = GoBot()

    func test00_login() async throws {
        let fm = FileManager.default
        
        let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        
        // TODO: untar fixtures archive into simulator
        let targetPath = appSupportDir
            .appending("/FBTT")
            .appending("/"+reproNetwork.hexEncodedString())
            .appending("/")
        
        // start fresh
        do {
            try fm.removeItem(atPath: targetPath)
        } catch {
            print(error)
            print("removing previous failed")
        }
        print("<==FIXTURES==>")
        // TODO: script this:
        // tar xvf ${SOURCE}/verse-ios/FBTT/FBTTUnitTests/testfixtures/GoSbot.tar -C \(fm.currentDirectoryPath)
        print("resource target: \(fm.currentDirectoryPath)")
        
        do {
            try fm.createDirectory(atPath: targetPath, withIntermediateDirectories: true, attributes: nil)
            try fm.copyItem(atPath: "GoSbot", toPath: targetPath.appending("/GoSbot"))
        } catch {
            XCTFail("warning: sorry - you need to manually unpack the tar file and copy it to the 'cwd: ' output above.")
            XCTAssertNil(error)
            return
        }
        
        let loginExpecation = self.expectation(description: "login")
        try await API_GoBot.bot.login(config: reproConfiguration, fromOnboarding: false)
    }
    
    // check we loaded all the messages from the fixtures repo
    func test02_replicateUpto() async {
        let statistics = await API_GoBot.bot.statistics()
        XCTAssertEqual(statistics.repo.feedCount, 200)
        XCTAssertEqual(statistics.db.lastReceivedMessage, -1)
        XCTAssertEqual(statistics.repo.messageCount, 6700)
        
        XCTAssertFalse(API_GoBot.bot.bot.repoFSCK(.Sequences))
    }
    
    // make sure view db is uptodate with gosbot repo
    func test03_refresh() {
        var refreshExpectation = self.expectation(description: "refresh")
        API_GoBot.bot.refresh(load: .short, queue: .main) { (result, took) in
            XCTAssertNotNil(try? result.get())
            print("ref1:\(took)")
            refreshExpectation.fulfill()
        }
        waitForExpectations(timeout: 10)
        
        // TODO: retrigger refesh after repair sync
        refreshExpectation = self.expectation(description: "refresh")
        API_GoBot.bot.refresh(load: .short, queue: .main) { (result, took) in
            XCTAssertNotNil(try? result.get())
            print("ref2:\(took)")
            refreshExpectation.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func test04_same_msgs() async {
        let statistics = await API_GoBot.bot.statistics()
        XCTAssertEqual(statistics.db.lastReceivedMessage, 6699)
        XCTAssertEqual(statistics.repo.messageCount, 6700)
        
        XCTAssertTrue(API_GoBot.bot.bot.repoFSCK(.Sequences))
    }

    func test05_refresh() {
        let refreshExpectation = self.expectation(description: "refresh")
        API_GoBot.bot.refresh(load: .short, queue: .main) { (result, _) in
            XCTAssertNotNil(try? result.get())
            refreshExpectation.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func test07_refresh() async {
        let refreshExpectation = self.expectation(description: "refresh")
        API_GoBot.bot.refresh(load: .short, queue: .main) { (result, _) in
            XCTAssertNotNil(try? result.get())
            refreshExpectation.fulfill()
        }
        await waitForExpectations(timeout: 10)
        let statistics = await API_GoBot.bot.statistics()
        XCTAssertEqual(statistics.db.lastReceivedMessage, 6699)
        XCTAssertEqual(statistics.repo.messageCount, 6700)
    }

    func test900_logout() async throws {
        try await API_GoBot.bot.logout()
    }
}
