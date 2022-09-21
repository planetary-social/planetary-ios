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
    var sut = GoBot()
    var workingDirectory: String?
    let fileManager = FileManager.default
    let userDefaultsSuiteName = "GoBotIntegrationTests"

    override func setUpWithError() throws {
        // We should refactor GoBot to use a configurable directory, so we don't clobber existing data every time we
        // run the unit tests. For now this will have to do.
        let workingDirectory = try XCTUnwrap(
            NSSearchPathForDirectoriesInDomains(
                .applicationSupportDirectory,
                .userDomainMask,
                true
            ).first?.appending("/FBTT")
        )

        // start fresh
        do { try fileManager.removeItem(atPath: workingDirectory) } catch { /* this is fine */ }

        self.workingDirectory = workingDirectory

        UserDefaults().removePersistentDomain(forName: userDefaultsSuiteName)
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: userDefaultsSuiteName))
        let welcomeService = WelcomeServiceAdapter(userDefaults: userDefaults)
        userDefaults.set(true, forKey: welcomeService.hasBeenWelcomedKey(for: botTestsKey.id))

        sut = GoBot(userDefaults: userDefaults, preloadedPubService: MockPreloadedPubService())

        let appConfig = AppConfiguration(with: botTestsKey)
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
        if let workingDirectory = workingDirectory {
            do {
                try fileManager.removeItem(atPath: workingDirectory)
            } catch {
                print(error)
            }
        }
    }

    func testGetRawMessage() throws {
        let keypairs = try sut.testingGetNamedKeypairs()
        let alice = try XCTUnwrap(keypairs["alice"])
        sut.testingPublish(as: "alice", content: Post(text: "Hello, World"))
        var source: String?
        alice.withGoString { gostr in
            if let rawPointer = ssbGetRawMessage(gostr, 1) {
                source = String(cString: rawPointer)
                free(rawPointer)
            }
        }
        XCTAssertNotNil(source)
        let data = try XCTUnwrap(try XCTUnwrap(source).data(using: .utf8))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["sequence"] as? Int, 1)
        XCTAssertEqual(json["author"] as? String, alice)
    }
}
