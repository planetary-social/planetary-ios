//
//  XCTest+Test.swift
//  FBTT
//
//  Created by Christoph on 1/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import XCTest

extension XCTestCase {

    // Convenience function to pause a script for a bit of time.  This internally
    // uses the waitForExpectations() construct, but doesn't require littering
    // the script code with expectations.  If the expectation times out, the test
    // will fail.
    @available(*, deprecated)
    func wait(for duration: TimeInterval = 2, label description: String = "wait") {
        let expectation = self.expectation(description: description)
        let deadline = DispatchTime.now() + Double(Int64(duration * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: deadline) { expectation.fulfill() }
        self.waitForExpectations(timeout: duration + 0.1)
    }
}
