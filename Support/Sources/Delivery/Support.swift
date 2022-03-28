//
//  Push.swift
//
//
//  Created by Martin Dutra on 10/9/21.
//

import Foundation
import UIKit

public class Support {

    public static let shared = Support(service: SupportServiceAdapter(ZendeskService()))

    var service: SupportService

    init(service: SupportService) {
        self.service = service
    }

    func mainViewController() -> UIViewController? {
        return service.mainViewController()
    }

    func articleViewController(_ article: SupportArticle) -> UIViewController? {
        return service.articleViewController(for: article)
    }

    func myTicketsViewController(from reporter: String?, botLog: Data?) -> UIViewController? {
        return service.myTicketsViewController(from: reporter, botLog: botLog)
    }

    func newTicketViewController(botLog: Data?) -> UIViewController? {
        return service.newTicketViewController(botLog: botLog)
    }

    func newTicketViewController(from reporter: String, reporting identity: String, name: String, botLog: Data?) -> UIViewController? {
        let identifier = Identifier(key: reporter)
        let author = Author(identifier: Identifier(key: identity), name: name)
        return service.newTicketViewController(from: identifier, author: author, botLog: botLog)
    }

    func newTicketViewController(from reporter: String, reporting contentRef: String, authorRef: String, authorName: String?, reason: SupportReason, view: UIView?, botLog: Data?) -> UIViewController? {
        let identifier = Identifier(key: reporter)
        let content = Content(
            identifier: Identifier(key: contentRef),
            author: Author(identifier: Identifier(key: authorRef), name: authorName),
            screenshot: view?.jpegData())
        return service.newTicketViewController(
            from: identifier,
            content: content,
            reason: reason,
            botLog: botLog)
    }
    
}
