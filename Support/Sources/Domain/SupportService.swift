//
//  SupportService.swift
//  
//
//  Created by Martin Dutra on 24/3/22.
//

import Foundation
import UIKit

/// SupportService provides functions to create tickets independently
/// of the Support third party (Zendesk at the moment) service
protocol SupportService {

    /// Creates a view controller to show when selecting show Help and Support
    func mainViewController() -> UIViewController?

    /// Creates a view controller that displays an article
    ///
    /// - parameter article: The article to display
    func articleViewController(for article: SupportArticle) -> UIViewController?

    /// Creates a view controller that displays the tickets the user has created in the past
    ///
    /// - parameter from: The identity of the logged in user
    /// - parameter botLog: A Data object containing the log of the go bot
    func myTicketsViewController(from identity: String?, botLog: Data?) -> UIViewController?

    /// Creates a view controller that reports a bug
    ///
    /// - parameter botLog: A Data object containing the log of the go bot
    func newTicketViewController(botLog: Data?) -> UIViewController?

    /// Creates a view controller that reports a profile
    ///
    /// - parameter from: The logged in user
    /// - parameter author: The profile to report
    /// - parameter botLog: A Data object containing the log of the go bot
    func newTicketViewController(from identifier: Identifier, author: Author, botLog: Data?) -> UIViewController?

    /// Creates a view controller that reports a content
    ///
    /// - parameter from: The logged in user
    /// - parameter content: The content to report
    /// - parameter reason: A reason why the user is reporting the content
    /// - parameter botLog: A Data object containing the log of the go bot
    func newTicketViewController(
        from identifier: Identifier,
        content: Content,
        reason: SupportReason,
        botLog: Data?
    ) -> UIViewController?
}
