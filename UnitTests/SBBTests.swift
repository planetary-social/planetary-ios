//
//  SBBTests.swift
//  UnitTests
//
//  Created by Martin Dutra on 19/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

class SBBTests: XCTestCase {

    /// The system under test
    var sut: GoBot!
    var workingDirectory: String!
    var userDefaults: UserDefaults!
    var appConfig: AppConfiguration!
    let fileManager = FileManager.default
    let userDefaultsSuiteName = "GoBotIntegrationTests"


    override func setUpWithError() throws {
        // We should refactor GoBot to use a configurable directory, so we don't clobber existing data every time we
        // run the unit tests. For now this will have to do.
        workingDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!
            .appending("/FBTT")

        // start fresh
        do { try fileManager.removeItem(atPath: workingDirectory) } catch { /* this is fine */ }

        UserDefaults().removePersistentDomain(forName: userDefaultsSuiteName)
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)
        let welcomeService = WelcomeServiceAdapter(userDefaults: userDefaults)
        userDefaults.set(true, forKey: welcomeService.hasBeenWelcomedKey(for: botTestsKey.id))

        sut = GoBot(userDefaults: userDefaults, preloadedPubService: MockPreloadedPubService())

        appConfig = AppConfiguration(with: botTestsKey)
        appConfig.network = botTestNetwork
        appConfig.hmacKey = botTestHMAC
        appConfig.bot = sut

        let loginExpectation = self.expectation(description: "login")
        sut.login(config: appConfig) { error in
            defer { loginExpectation.fulfill() }
            XCTAssertNil(error)
        }
        self.wait(for: [loginExpectation], timeout: 10)

        let nicks = ["alice", "bob"]
        for nick in nicks {
            try sut.testingCreateKeypair(nick: nick)
        }
        try super.setUpWithError()
    }

    override func tearDown() async throws {
        try await super.tearDown()

        do {
            try await sut.logout()
        } catch {
            guard case BotError.notLoggedIn = error else {
                throw error
            }
        }
        await sut.exit()
        do {
            try fileManager.removeItem(atPath: workingDirectory)
        } catch {
            print(error)
        }
    }

    func testGetRawMessage() throws {
        let keypairs = try sut.testingGetNamedKeypairs()
        let alice = try XCTUnwrap(keypairs["alice"])
        let bob = try XCTUnwrap(keypairs["bob"])
        let msg = sut.testingPublish(as: "alice", content: Post(text: "Hello, World"))
        var raw: String?
        alice.withGoString { gostr in
            if let rawPointer = ssbGetRawMessage(gostr, 1) {
                raw = String(cString: rawPointer)
                free(rawPointer)
            }
        }
        XCTAssertNotNil(raw)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
