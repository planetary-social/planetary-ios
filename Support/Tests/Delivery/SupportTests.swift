//
//  SupportTests.swift
//  
//
//  Created by Martin Dutra on 1/4/22.
//

import Foundation
@testable import Support
import XCTest

class SupportTests: XCTestCase {

    var support: Support?
    var supportService: SupportServiceMock?

    override func setUp() {
        super.setUp()
        let supportService = SupportServiceMock()
        support = Support(service: supportService)
        self.supportService = supportService
    }

    func testMainViewController() throws {
        let result = support?.mainViewController()
        let supportService = try XCTUnwrap(supportService)
        XCTAssertTrue(supportService.mainCalled)
        XCTAssertNil(result)
    }

    func testArticleViewController() throws {
        let article = SupportArticle.whatIsPlanetary
        let result = support?.articleViewController(article)
        let supportService = try XCTUnwrap(supportService)
        XCTAssertTrue(supportService.articleCalled)
        XCTAssertNil(result)
    }

    func testMyTicketsViewController() throws {
        let result = support?.myTicketsViewController(from: "test-identity", botLog: nil)
        let supportService = try XCTUnwrap(supportService)
        XCTAssertTrue(supportService.myTicketsCalled)
        XCTAssertNil(result)
    }

    func testNewTicketViewController() throws {
        let result = support?.newTicketViewController(botLog: nil)
        let supportService = try XCTUnwrap(supportService)
        XCTAssertTrue(supportService.newTicketCalled)
        XCTAssertNil(result)
    }

    func testNewAuthorTicketViewController() throws {
        let result = support?.newTicketViewController(
            from: "test-identity",
            reporting: "author-ref",
            name: "author-name",
            botLog: nil
        )
        let supportService = try XCTUnwrap(supportService)
        XCTAssertTrue(supportService.newAuthorTicketCalled)
        XCTAssertNil(result)
    }

    func testNewContentTicketViewController() throws {
        let result = support?.newTicketViewController(
            from: "test-identity",
            reporting: "content-ref",
            authorRef: "author-ref",
            authorName: "author-name",
            reason: .copyright,
            view: nil,
            botLog: nil
        )
        let supportService = try XCTUnwrap(supportService)
        XCTAssertTrue(supportService.newContentTicketCalled)
        XCTAssertNil(result)
    }

    func testNewContentTicketViewControllerWithView() throws {
        let view = UIView()
        let result = support?.newTicketViewController(
            from: "test-identity",
            reporting: "content-ref",
            authorRef: "author-ref",
            authorName: "author-name",
            reason: .copyright,
            view: view,
            botLog: nil
        )
        let supportService = try XCTUnwrap(supportService)
        XCTAssertTrue(supportService.newContentTicketCalled)
        XCTAssertNil(result)
    }
}
