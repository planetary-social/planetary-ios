//
//  APIService.swift
//  
//
//  Created by Martin Dutra on 25/3/22.
//

import Foundation
import UIKit

/// APIService provides functions to connect and send tickets to a Support service
protocol APIService {

    /// Creates a view controller to show when selecting show Help and Support
    func mainViewController() -> UIViewController?

    /// Creates a view controller that displays an article
    ///
    /// - parameter article: The article to display
    func articleViewController(article: SupportArticle) -> UIViewController?

    /// Creates a view controller that displays the tickets the user has created in the past
    ///
    /// - parameter reporter: The identity of the logged in user
    /// - parameter attachments: Attachments to send to the Support service (for instance, logs)
    func myTicketsViewController(reporter: Identifier, attachments: [Attachment]) -> UIViewController?

    /// Creates a view controller that creates a ticket
    ///
    /// - parameter reporter: The identity of the logged in user
    /// - parameter subject: What the user is reporting (a bug, a content, a profile)
    /// - parameter reason: A reason why the user is reporting something
    /// - parameter attachments: Attachments to send to the Support
    /// service (for instance, profile or content identifiers logs, screenshots)
    func newTicketViewController(
        reporter: Identifier,
        subject: Subject,
        reason: SupportReason?,
        attachments: [Attachment]
    ) -> UIViewController?
}
