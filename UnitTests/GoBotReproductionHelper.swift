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

let reproNetwork = NetworkKey.planetary
let reproHMAC = HMACKey.planetary

import XCTest


class API_GoBot: XCTestCase {
    
    static var bot = GoBot()

    func test00_login() {
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
        
        API_GoBot.bot.login(network: reproNetwork, hmacKey: reproHMAC, secret: reproKey) {
            error in
            XCTAssertNil(error)
        }

        self.wait()
    }
    
    // check we loaded all the messages from the fixtures repo
    func test02_replicateUpto() {
        XCTAssertEqual(API_GoBot.bot.statistics.repo.feedCount, 200)
        XCTAssertEqual(API_GoBot.bot.statistics.db.lastReceivedMessage, -1)
        XCTAssertEqual(API_GoBot.bot.statistics.repo.messageCount, 6700)
        
        XCTAssertFalse(API_GoBot.bot.bot.repoFSCK(.Sequences))
    }
    
    // make sure view db is uptodate with gosbot repo
    func test03_refresh() {
        API_GoBot.bot.refresh(load: .short, queue: .main) {
            (err, took) in
            XCTAssertNil(err)
            print("ref1:\(took)")
        }
        self.wait(for: 30)
        
        // TODO: retrigger refesh after repair sync
        API_GoBot.bot.refresh(load: .short, queue: .main) {
            (err, took) in
            XCTAssertNil(err)
            print("ref2:\(took)")
        }
        self.wait(for: 10)
    }

    func test04_same_msgs() {
        XCTAssertEqual(API_GoBot.bot.statistics.db.lastReceivedMessage, 6699)
        XCTAssertEqual(API_GoBot.bot.statistics.repo.messageCount, 6700)
        
        XCTAssertTrue(API_GoBot.bot.bot.repoFSCK(.Sequences))
    }

    func test05_refresh() {
        API_GoBot.bot.refresh(load: .short, queue: .main) {
            (err, took) in
            XCTAssertNil(err)
        }
        self.wait()
    }

    func test07_refresh() {
        API_GoBot.bot.refresh(load: .short, queue: .main) {
            (err, took) in
            XCTAssertNil(err)
        }
        self.wait()
        XCTAssertEqual(API_GoBot.bot.statistics.db.lastReceivedMessage, 6699)
        XCTAssertEqual(API_GoBot.bot.statistics.repo.messageCount, 6700)
    }

    func test900_logout() {
        API_GoBot.bot.logout() {
            error in
            XCTAssertNil(error)
        }
        
        self.wait()
    }
}



