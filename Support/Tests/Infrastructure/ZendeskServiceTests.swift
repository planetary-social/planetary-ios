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

    var service: ZendeskService!

    override func setUp() {
        service = ZendeskService(keys: Keys(bundle: .module))
    }

    func testMainViewController() throws {
        let service = try XCTUnwrap(service)
        XCTAssertNotNil(service.mainViewController())
    }

    func testArticleViewController() throws {
        let service = try XCTUnwrap(service)
        let articles: [SupportArticle] = [.editPost, .faq, .termsOfService, .privacyPolicy, .whatIsPlanetary]
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
        XCTAssertNotNil(service.newTicketViewController(
            reporter: reporter,
            subject: SupportSubject.contentReport,
            reason: SupportReason.copyright,
            attachments: attachments
        ))
    }
}
