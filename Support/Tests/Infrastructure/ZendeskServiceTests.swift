//
//  ZendeskServiceTests.swift
//  
//
//  Created by Martin Dutra on 1/4/22.
//

import Foundation
@testable import Support
import XCTest
import Secrets

final class ZendeskServiceTests: XCTestCase {

    var service: ZendeskService?

    override func setUp() {
        super.setUp()
        service = ZendeskService(keys: Keys(bundle: .module))
    }

    func testMainViewController() throws {
        let service = try XCTUnwrap(service)
        XCTAssertNotNil(service.mainViewController())
    }

    func testArticleViewController() throws {
        let service = try XCTUnwrap(service)
        let articles: [SupportArticle] = [
            .editPost,
            .frequentlyAskedQuestions,
            .termsOfService,
            .privacyPolicy,
            .whatIsPlanetary
        ]
        articles.forEach { article in
            XCTAssertNotNil(service.articleViewController(article: article))
        }
    }

    func testMyTicketsViewController() throws {
        let service = try XCTUnwrap(service)
        let reporter = Identifier(key: nil)
        let attachments = [Attachment]()
        XCTAssertNotNil(service.myTicketsViewController(reporter: reporter, attachments: attachments))
    }

    func testNewTicketViewController() throws {
        let service = try XCTUnwrap(service)
        let reporter = Identifier(key: nil)
        let attachments = [Attachment]()
        let viewController = service.newTicketViewController(
            reporter: reporter,
            subject: .contentReport,
            reason: .copyright,
            attachments: attachments
        )
        XCTAssertNotNil(viewController)
    }
}
