//
//  OnboardingTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

/// Integration tests to verify that various aspects of the onboarding flow are working.
class OnboardingTests: XCTestCase {

    // TODO: Move this into ViewDatabasePreloadTest
    /// Loads up the preloaded feeds from Preload.bundle and verifies that we can parse them into [KeyValue] and that
    /// they are not empty.
    func testPreloadedFeedsAreParseable() throws {
        let testingBundle = try XCTUnwrap(Bundle(for: type(of: self)))
        let preloadURL = try XCTUnwrap(testingBundle.url(forResource:"Preload", withExtension:"bundle"))
        let preloadBundle = try XCTUnwrap(Bundle(url: preloadURL))
        let feedURLs = try XCTUnwrap(preloadBundle.urls(forResourcesWithExtension: "json", subdirectory: "Feeds"))
        XCTAssertEqual(feedURLs.count, 2)
        try feedURLs.forEach { url in
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
            XCTAssertEqual(msgs.isEmpty, false)
        }
    }
}
