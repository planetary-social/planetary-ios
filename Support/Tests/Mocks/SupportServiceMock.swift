//
//  SupportServiceMock.swift
//  
//
//  Created by Martin Dutra on 1/4/22.
//

import Foundation
@testable import Support
import UIKit

class SupportServiceMock: SupportService {

    var mainCalled = false
    var articleCalled = false
    var myTicketsCalled = false
    var newTicketCalled = false
    var newAuthorTicketCalled = false
    var newContentTicketCalled = false

    func mainViewController() -> UIViewController? {
        mainCalled = true
        return nil
    }

    func articleViewController(for article: SupportArticle) -> UIViewController? {
        articleCalled = true
        return nil
    }

    func myTicketsViewController(from identity: String?, botLog: Data?) -> UIViewController? {
        myTicketsCalled = true
        return nil
    }

    func newTicketViewController(botLog: Data?) -> UIViewController? {
        newTicketCalled = true
        return nil
    }

    func newTicketViewController(from identifier: Identifier, author: Author, botLog: Data?) -> UIViewController? {
        newAuthorTicketCalled = true
        return nil
    }

    func newTicketViewController(from identifier: Identifier, content: Content, reason: SupportReason, botLog: Data?) -> UIViewController? {
        newContentTicketCalled = true
        return nil
    }


}
