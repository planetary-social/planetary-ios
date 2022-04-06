//
//  Push.swift
//
//
//  Created by Martin Dutra on 10/9/21.
//

import Foundation
import UIKit

/// Support is a simple utility to show the Help and Support section
public class Support {

    /// A shared singleton that shoul be the main entry of Support
    public static let shared = Support(service: SupportServiceAdapter(ZendeskService()))

    var service: SupportService

    init(service: SupportService) {
        self.service = service
    }

    /// Creates a UIViewController that displays the main entry of support, the Help and Support entry in Planetary
    public func mainViewController() -> UIViewController? {
        service.mainViewController()
    }

    /// Creates a UIViewController that displays an article
    ///
    /// - parameter article: The article to display
    public func articleViewController(_ article: SupportArticle) -> UIViewController? {
        service.articleViewController(for: article)
    }

    /// Creates a UIViewController that shows the tickets the user created in the past
    ///
    /// - parameter from: The identity of the logged in user
    /// - parameter botLog: A Data object containing the log of the go bot
    public func myTicketsViewController(from reporter: String?, botLog: Data?) -> UIViewController? {
        service.myTicketsViewController(from: reporter, botLog: botLog)
    }

    /// Creates a UIViewController that lets the user submit a bug
    ///
    /// - parameter botLog: A Data object containing the log of the go bot
    public func newTicketViewController(botLog: Data?) -> UIViewController? {
        service.newTicketViewController(botLog: botLog)
    }

    /// Creates a UIViewController that lets the user report an abusive profile
    ///
    /// - parameter reporter: The identity of the logged in user
    /// - parameter profile: The profile to report
    /// - parameter botLog: A Data object containing the log of the go bot
    public func newTicketViewController(reporter: String, profile: SupportProfile, botLog: Data?) -> UIViewController? {
        let identifier = Identifier(key: reporter)
        let author = Author(identifier: Identifier(key: profile.identifier), name: profile.name)
        return service.newTicketViewController(
            from: identifier,
            author: author,
            botLog: botLog
        )
    }

    /// Creates a UIViewController that lets the user report an offensive content
    ///
    /// - parameter reporter: The identity of the logged in user
    /// - parameter content: The content to report
    /// - parameter botLog: A Data object containing the log of the go bot
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
