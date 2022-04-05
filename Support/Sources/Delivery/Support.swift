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

    public func mainViewController() -> UIViewController? {
        service.mainViewController()
    }

    public func articleViewController(_ article: SupportArticle) -> UIViewController? {
        service.articleViewController(for: article)
    }

    public func myTicketsViewController(from reporter: String?, botLog: Data?) -> UIViewController? {
        service.myTicketsViewController(from: reporter, botLog: botLog)
    }

    public func newTicketViewController(botLog: Data?) -> UIViewController? {
        service.newTicketViewController(botLog: botLog)
    }

    public func newTicketViewController(reporter: String, profile: SupportProfile, botLog: Data?) -> UIViewController? {
        let identifier = Identifier(key: reporter)
        let author = Author(identifier: Identifier(key: profile.identifier), name: profile.name)
        return service.newTicketViewController(
            from: identifier,
            author: author,
            botLog: botLog
        )
    }

    public func newTicketViewController(reporter: String, content: SupportContent, botLog: Data?) -> UIViewController? {
        let identifier = Identifier(key: reporter)
        let reason = content.reason
        let content = Content(
            identifier: Identifier(key: content.identifier),
            author: Author(identifier: Identifier(key: content.profile?.identifier), name: content.profile?.name),
            screenshot: content.view?.jpegData()
        )
        return service.newTicketViewController(
            from: identifier,
            content: content,
            reason: reason,
            botLog: botLog
        )
    }
}
