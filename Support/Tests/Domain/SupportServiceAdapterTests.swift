//
//  SupportServiceAdapterTests.swift
//  
//
//  Created by Martin Dutra on 1/4/22.
//

import Foundation
@testable import Support
import XCTest
import Secrets

final class SupportServiceAdapterTests: XCTestCase {

    var service: SupportServiceAdapter?
    var apiService: APIServiceMock?

    override func setUp() {
        super.setUp()
        let apiService = APIServiceMock()
        service = SupportServiceAdapter(apiService)
        self.apiService = apiService
    }

    func testMainViewController() throws {
        let result = service?.mainViewController()
        let apiService = try XCTUnwrap(apiService)
        XCTAssertEqual(apiService.mainViewController(), result)
        XCTAssertTrue(apiService.mainCalled)
    }

    func testArticleViewController() throws {
        let article = SupportArticle.whatIsPlanetary
        let result = service?.articleViewController(for: article)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertEqual(apiService.articleViewController(article: article), result)
        XCTAssertTrue(apiService.articleCalled)
    }

    func testMyTicketsViewController() throws {
        let identity = "test-identity"
        let result = service?.myTicketsViewController(from: identity, botLog: nil)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.myTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, identity)
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "app_log.txt" }))

    }

    func testMyTicketsViewControllerWithBotLog() throws {
        let identity = "test-identity"
        let botLog = Data()
        let result = service?.myTicketsViewController(from: identity, botLog: botLog)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.myTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, identity)
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "app_log.txt" }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "bot_log.txt" }))

    }

    func testNewTicketViewController() throws {
        let result = service?.newTicketViewController(botLog: nil)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.newTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, "not-logged-in")
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "app_log.txt" }))
    }

    func testNewTicketViewControllerWithBotLog() throws {
        let botLog = "hello".data(using: .utf8)
        let result = service?.newTicketViewController(botLog: botLog)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.newTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, "not-logged-in")
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "bot_log.txt" }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.data == botLog }))
    }

    func testNewAuthorTicketViewController() throws {
        let identity = Identifier(key: "test-identity")
        let authorIdentity = "another-identity"
        let author = Author(identifier: Identifier(key: authorIdentity), name: nil)
        let result = service?.newTicketViewController(from: identity, author: author, botLog: nil)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.newTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, identity.key)
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "app_log.txt" }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == authorIdentity }))
    }

    func testNewAuthorTicketViewControllerWithAuthorName() throws {
        let identity = Identifier(key: "test-identity")
        let authorIdentity = "another-identity"
        let authorName = "author-name"
        let author = Author(identifier: Identifier(key: authorIdentity), name: authorName)
        let result = service?.newTicketViewController(from: identity, author: author, botLog: nil)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.newTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, identity.key)
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "app_log.txt" }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == authorName }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.data == authorIdentity.data(using: .utf8) }))
    }

    func testNewContentTicketViewController() throws {
        let identity = Identifier(key: "test-identity")
        let authorIdentity = "another-identity"
        let author = Author(identifier: Identifier(key: authorIdentity), name: nil)
        let contentKey = "content-ref"
        let contentIdentifier = Identifier(key: contentKey)
        let content = Content(identifier: contentIdentifier, author: author, screenshot: nil)
        let result = service?.newTicketViewController(from: identity, content: content, reason: .copyright, botLog: nil)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.newTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, identity.key)
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "app_log.txt" }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == authorIdentity }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "content-identifier" }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.data == contentKey.data(using: .utf8) }))
    }

    func testNewContentTicketViewControllerWithScreenshot() throws {
        let identity = Identifier(key: "test-identity")
        let authorIdentity = "another-identity"
        let author = Author(identifier: Identifier(key: authorIdentity), name: nil)
        let contentIdentifier = Identifier(key: "content-ref")
        let screenshot = "hi".data(using: .utf8)
        let content = Content(identifier: contentIdentifier, author: author, screenshot: screenshot)
        let result = service?.newTicketViewController(from: identity, content: content, reason: .copyright, botLog: nil)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.lastAttachments.contains(where: {$0.data == screenshot}))
    }

    func testNewContentTicketViewControllerWithAuthorName() throws {
        let identity = Identifier(key: "test-identity")
        let authorIdentity = "another-identity"
        let authorName = "some name"
        let author = Author(identifier: Identifier(key: authorIdentity), name: authorName)
        let contentKey = "content-ref"
        let contentIdentifier = Identifier(key: contentKey)
        let content = Content(identifier: contentIdentifier, author: author, screenshot: nil)
        let result = service?.newTicketViewController(from: identity, content: content, reason: .copyright, botLog: nil)
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.newTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, identity.key)
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "app_log.txt" }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == authorName }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.data == authorIdentity.data(using: .utf8) }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.filename == "content-identifier" }))
        XCTAssertTrue(apiService.lastAttachments.contains(where: { $0.data == contentKey.data(using: .utf8) }))
    }

    func testNewContentTicketViewControllerWithBotLog() throws {
        let identity = Identifier(key: "test-identity")
        let authorIdentity = "another-identity"
        let authorName = "some name"
        let author = Author(identifier: Identifier(key: authorIdentity), name: authorName)
        let contentIdentifier = Identifier(key: "content-ref")
        let content = Content(identifier: contentIdentifier, author: author, screenshot: nil)
        let botLog = "hello".data(using: .utf8)
        let result = service?.newTicketViewController(
            from: identity,
            content: content,
            reason: .copyright,
            botLog: botLog
        )
        XCTAssertNil(result)
        let apiService = try XCTUnwrap(apiService)
        XCTAssertTrue(apiService.newTicketsCalled)
        XCTAssertEqual(apiService.lastReporter.key, identity.key)
        XCTAssertTrue(apiService.lastAttachments.contains(where: {$0.filename == "bot_log.txt"}))
        XCTAssertTrue(apiService.lastAttachments.contains(where: {$0.data == botLog}))
    }
}
