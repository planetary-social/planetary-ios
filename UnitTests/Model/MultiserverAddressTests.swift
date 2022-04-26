//
//  MultiserverAddressTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 4/21/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

class MultiserverAddressTests: XCTestCase {

    func testInitFromStringGivenSystemPub() {
        let string = "net:four.planetary.pub:8008~shs:5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw="
        let multiserverAddress = MultiserverAddress(string: string)
        XCTAssertEqual(multiserverAddress?.key, "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=")
        XCTAssertEqual(multiserverAddress?.host, "four.planetary.pub")
        XCTAssertEqual(multiserverAddress?.port, 8008)
        XCTAssertEqual(multiserverAddress?.rawValue, string)
    }
    
    func testInitFromStringGivenDiacritics() {
        let string = "net:âßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé:8008~shs:5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw="
        let multiserverAddress = MultiserverAddress(string: string)
        XCTAssertEqual(multiserverAddress?.key, "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=")
        XCTAssertEqual(multiserverAddress?.host, "âßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé")
        XCTAssertEqual(multiserverAddress?.port, 8008)
        XCTAssertEqual(multiserverAddress?.rawValue, string)
    }
    
    func testInitFromStringGivenIPHost() {
        let string = "net:192.168.1.1:8008~shs:5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw="
        let multiserverAddress = MultiserverAddress(string: string)
        XCTAssertEqual(multiserverAddress?.key, "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=")
        XCTAssertEqual(multiserverAddress?.host, "192.168.1.1")
        XCTAssertEqual(multiserverAddress?.port, 8008)
        XCTAssertEqual(multiserverAddress?.rawValue, string)
    }
    
    func testInitMemberwiseGivenSystemPub() {
        let string = "net:four.planetary.pub:8008~shs:5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw="
        let multiserverAddress = MultiserverAddress(
            key: "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=",
            host: "four.planetary.pub",
            port: 8008
        )
        XCTAssertEqual(multiserverAddress.key, "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=")
        XCTAssertEqual(multiserverAddress.host, "four.planetary.pub")
        XCTAssertEqual(multiserverAddress.port, 8008)
        XCTAssertEqual(multiserverAddress.rawValue, string)
    }
    
    func testInitMemberwiseGivenDiacritics() {
        let string = "net:âßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé:8008~shs:5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw="
        let multiserverAddress = MultiserverAddress(
            key: "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=",
            host: "âßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé",
            port: 8008
        )
        XCTAssertEqual(multiserverAddress.key, "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=")
        XCTAssertEqual(multiserverAddress.host, "âßàÁâãóôþüúðæåïçèõöÿýòäœêëìíøùîûñé")
        XCTAssertEqual(multiserverAddress.port, 8008)
        XCTAssertEqual(multiserverAddress.rawValue, string)
    }
    
    func testInitMemberwiseGivenIPHost() {
        let string = "net:192.168.1.1:8008~shs:5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw="
        let multiserverAddress = MultiserverAddress(
            key: "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=",
            host: "192.168.1.1",
            port: 8008
        )
        XCTAssertEqual(multiserverAddress.key, "5KDK98cjIQ8bPoBkvp7bCwBXoQMlWpdIbCFyXER8Lbw=")
        XCTAssertEqual(multiserverAddress.host, "192.168.1.1")
        XCTAssertEqual(multiserverAddress.port, 8008)
        XCTAssertEqual(multiserverAddress.rawValue, string)
    }
}
