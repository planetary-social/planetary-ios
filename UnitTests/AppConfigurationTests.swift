//
//  AppConfigurationTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 5/9/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import KeychainSwift
import XCTest

extension XCTestCase {

    func configuration() -> AppConfiguration {
        let data = self.data(for: "Secret.json")
        let secret = try? JSONDecoder().decode(Secret.self, from: data)
        let configuration = AppConfiguration(with: secret!)
        return configuration
    }
}

class AppConfigurationTests: XCTestCase {

    func test_archiving() {
        let configuration = self.configuration()
        let data = configuration.toData()
        XCTAssertNotNil(data)
        let configurationFromData = AppConfiguration.from(data!)
        XCTAssertNotNil(configurationFromData)
    }
}
