//
//  XCTBlockExpectation.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 4/20/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

/// Like XCTNSPredicateExpectation but way faster
class XCTBlockExpectation: XCTestExpectation {
    init(condition: @escaping () -> Bool) {
        super.init(description: "XCTBlockExpectation")
        waitForCondition(condition: condition)
    }
    
    private func waitForCondition(condition: @escaping () -> Bool) {
        DispatchQueue.main.async { [weak self] in
            if condition() {
                self?.fulfill()
            } else {
                self?.waitForCondition(condition: condition)
            }
        }
    }
}
