//
//  GoBotTestExtension.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/19/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

// testing only functions on the Go side
extension GoBot {
    func testRefresh(_ tc: XCTestCase) {
        // No test pubs are set up right now, no need to try to sync with them.
//        let syncExpectation = tc.expectation(description: "Sync")
//        let peers = Environment.Constellation.stars.map { $0.toPeer() }
//        self.sync(queue: .main, peers: peers) {
//            error, _, _ in
//            XCTAssertNil(error)
//            syncExpectation.fulfill()
//        }
//        tc.wait(for: [syncExpectation], timeout: 30)

        let refreshExpectation = tc.expectation(description: "Refresh")
        self.refresh(load: .short, queue: .main) {
            error, _, _ in
            XCTAssertNil(error, "view refresh failed")
            refreshExpectation.fulfill()
        }
        tc.wait(for: [refreshExpectation], timeout: 30)
    }
    
    func testingCreateKeypair(nick: String) throws {
        var err: Error?
        nick.withGoString {
            let ok = ssbTestingMakeNamedKey($0)
            if ok != 0 {
                err = GoBotError.unexpectedFault("failed to create test key")
            }
        }

        if let e = err { throw e }
    }

    func testingGetNamedKeypairs() throws -> [String: Identity] {
        guard let cstr = ssbTestingAllNamedKeypairs() else {
            throw GoBotError.unexpectedFault("failed to load keypairs")
        }
        let data = String(cString: cstr).data(using: .utf8)!

        var pubkeys: [String: Identity] = [:] // map we want to return

        let json = try JSONSerialization.jsonObject(with: data, options: [])
        if let dictionary = json as? [String: Any] {
            for (name, val) in dictionary {
                pubkeys[name] = val as? Identity
            }
        }
        return pubkeys
    }

    func testingPublish(as nick: String, recipients: [Identity]? = nil, content: ContentCodable) -> MessageIdentifier {
        let c = try! content.encodeToData().string()!
        var identifier: MessageIdentifier?
        nick.withGoString { goStrNick in
            c.withGoString { goStrContent in

                if let recps = recipients { // private mode
                    if recps.count < 1 {
                        XCTFail("need at least one recipient")
                        return
                    }
                    recps.joined(separator: ";").withGoString { recpsJoined in
                        guard let refCstr = ssbTestingPublishPrivateAs(goStrNick, goStrContent, recpsJoined) else {
                            XCTFail("private publish failed")
                            return
                        }
                        identifier = String(cString: refCstr)
                    }
                    return
                }

                // public mode
                guard let refCstr = ssbTestingPublishAs(goStrNick, goStrContent) else {
                    XCTFail("publish failed!")
                    return
                }

                identifier = String(cString: refCstr)
            }
        }
        let id = identifier!
        XCTAssertTrue(id.hasPrefix("%"))
        XCTAssertTrue(id.hasSuffix("ggmsg-v1"))
        print(c)
        return id
    }

    func testingPublish(as nick: String, raw: Data) -> MessageIdentifier {
        let content = raw.string()!
        var identifier: MessageIdentifier?
        nick.withGoString { goStrNick in
            content.withGoString { goStrContent in

                guard let refCstr = ssbTestingPublishAs(goStrNick, goStrContent) else {
                    XCTFail("raw publish failed!")
                    return
                }

                identifier = String(cString: refCstr)
            }
        }
        guard let id = identifier else {
            XCTFail("no identifier from raw publish")
            return "%publish-failed.wrong"
        }
        XCTAssertTrue(id.hasPrefix("%"))
        XCTAssertTrue(id.hasSuffix("ggmsg-v1"))
        return id
    }
}
