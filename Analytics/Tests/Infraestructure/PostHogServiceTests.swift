//
//  PostHogServiceTests.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import XCTest
@testable import Analytics
import PostHog
import Secrets

final class PosthogServiceTests: XCTestCase {

    private var middleware: MiddlewareMock!
    private var service: PostHogService!

    override func setUp() {
        middleware = MiddlewareMock()
        service = PostHogService(keys: Keys(bundle: .module),
                                 middlewares: [middleware])
    }

    func testWithoutKey() {
        service = PostHogService(keys: Keys(bundle: .main),
                                 middlewares: [middleware])
        XCTAssertFalse(service.isEnabled)
    }

    func testIsEnabled() throws {
        let posthog = try XCTUnwrap(service.posthog)
        XCTAssertTrue(service.isEnabled)
        service.optOut()
        XCTAssertFalse(service.isEnabled)
    }

    func testIdentify() throws {
        let posthog = try XCTUnwrap(service.posthog)
        XCTAssertTrue(posthog.enabled)
        let identity = Identity(identifier: "user-hash", name: "John Doe", network: "network-hash")
        service.identify(identity: identity)
        XCTAssertEqual(middleware.lastContext?.eventType, .identify)
    }

    func testIdentifyWithoutName() throws {
        let posthog = try XCTUnwrap(service.posthog)
        XCTAssertTrue(posthog.enabled)
        let identity = Identity(identifier: "user-hash", name: nil, network: "network-hash")
        service.identify(identity: identity)
        XCTAssertEqual(middleware.lastContext?.eventType, .identify)
    }

    func testTrack() throws {
        let posthog = try XCTUnwrap(service.posthog)
        XCTAssertTrue(posthog.enabled)
        service.track(event: "test", params: nil)
        XCTAssertEqual(middleware.lastContext?.eventType, .capture)
    }

    func testForget() throws {
        let posthog = try XCTUnwrap(service.posthog)
        XCTAssertTrue(posthog.enabled)
        service.forget()
        XCTAssertEqual(middleware.lastContext?.eventType, .reset)
    }

    func testOptIn() throws {
        let posthog = try XCTUnwrap(service.posthog)
        XCTAssertTrue(posthog.enabled)
        service.optOut()
        XCTAssertFalse(posthog.enabled)
        service.optIn()
        XCTAssertTrue(posthog.enabled)
    }

}
