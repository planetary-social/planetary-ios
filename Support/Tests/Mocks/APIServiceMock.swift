//
//  APIServiceMock.swift
//  
//
//  Created by Martin Dutra on 1/4/22.
//

import Foundation
@testable import Support
import UIKit

class APIServiceMock: APIService {

    var mainCalled = false
    var articleCalled = false
    var myTicketsCalled = false
    var newTicketsCalled = false

    var lastReporter = Identifier(key: nil)
    var lastAttachments = [Attachment]()

    func mainViewController() -> UIViewController? {
        mainCalled = true
        return nil
    }

    func articleViewController(article: SupportArticle) -> UIViewController? {
        articleCalled = true
        return nil
    }

    func myTicketsViewController(reporter: Identifier, attachments: [Attachment]) -> UIViewController? {
        myTicketsCalled = true
        lastReporter = reporter
        lastAttachments = attachments
        return nil
    }

    func newTicketViewController(
        reporter: Identifier,
        subject: SupportSubject,
        reason: SupportReason?,
        attachments: [Attachment]
    ) -> UIViewController? {
        newTicketsCalled = true
        lastReporter = reporter
        lastAttachments = attachments
        return nil
    }
}
