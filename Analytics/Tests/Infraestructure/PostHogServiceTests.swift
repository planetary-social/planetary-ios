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

    func testIsEnabled() {
        XCTAssertTrue(service.isEnabled)
    }

    func testIdentify() {
        guard let posthog = service.posthog else {
            XCTFail("posthog variable not initialized")
            return
        }
        XCTAssertTrue(posthog.enabled)
        let identity = Identity(identifier: "user-hash", name: "John Doe", network: "network-hash")
        service.identify(identity: identity)
        XCTAssertEqual(middleware.lastContext?.eventType, .identify)
    }

    func testTrack() {
        guard let posthog = service.posthog else {
            XCTFail("posthog variable not initialized")
            return
        }
        XCTAssertTrue(posthog.enabled)
        service.track(event: "test", params: nil)
        XCTAssertEqual(middleware.lastContext?.eventType, .capture)
    }

    func testForget() {
        guard let posthog = service.posthog else {
            XCTFail("posthog variable not initialized")
            return
        }
        XCTAssertTrue(posthog.enabled)
        service.forget()
        XCTAssertEqual(middleware.lastContext?.eventType, .reset)
    }

}
