//
//  AppConfigurationTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 5/9/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import KeychainSwift
import XCTest

// swiftlint:disable implicitly_unwrapped_optional 

class AppConfigurationTests: XCTestCase {
    
    var secret: Secret!
    
    override func setUp() async throws {
        try await super.setUp()
        let data = self.data(for: "Secret.json")
        secret = try JSONDecoder().decode(Secret.self, from: data)
    }

    func test_archiving() throws {
        // Arrange
        let configuration = AppConfiguration(with: secret)
        configuration.name = "Test Configuration"
        configuration.network = NetworkKey(base64: "123")
        configuration.hmacKey = HMACKey(base64: "456")
        configuration.bot = FakeBot()
        configuration.numberOfPublishedMessages = 999
        configuration.joinedPlanetarySystem = true
        
        // Act
        let data = try XCTUnwrap(configuration.toData())
        let configurationFromData = try XCTUnwrap(AppConfiguration.from(data))
        
        // Assert
        XCTAssertEqual(configurationFromData.name, configuration.name)
        XCTAssertEqual(configurationFromData.network, configuration.network)
        XCTAssertEqual(configurationFromData.secret, configuration.secret)
        // XCTAssert(configurationFromData.bot === FakeBot.shared)
        XCTAssertEqual(configurationFromData.hmacKey, configuration.hmacKey)
        XCTAssertEqual(configurationFromData.numberOfPublishedMessages, configuration.numberOfPublishedMessages)
        XCTAssertEqual(configurationFromData.joinedPlanetarySystem, configuration.joinedPlanetarySystem)
    }
    
    func testDefaultNumberOfPublishedMessages() {
        let sut = AppConfiguration(with: secret)
        XCTAssertEqual(sut.numberOfPublishedMessages, 0)
    }
    
    func testDefaultJoinedPlanetarySystem() {
        let sut = AppConfiguration(with: secret)
        XCTAssertEqual(sut.joinedPlanetarySystem, false)
    }
}
