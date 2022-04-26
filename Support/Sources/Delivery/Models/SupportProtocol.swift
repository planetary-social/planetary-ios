//
//  SupportProtocol.swift
//  
//
//  Created by Martin Dutra on 26/4/22.
//

import Foundation
import UIKit

public protocol SupportProtocol {
    /// Creates a UIViewController that displays the main entry of support, the Help and Support entry in Planetary
    func mainViewController() -> UIViewController?

    /// Creates a UIViewController that displays an article
    ///
    /// - parameter article: The article to display
    func articleViewController(_ article: SupportArticle) -> UIViewController?

    /// Creates a UIViewController that shows the tickets the user created in the past
    ///
    /// - parameter from: The identity of the logged in user
    /// - parameter botLog: A Data object containing the log of the go bot
    func myTicketsViewController(from reporter: String?, botLog: Data?) -> UIViewController?

    /// Creates a UIViewController that lets the user submit a bug
    ///
    /// - parameter botLog: A Data object containing the log of the go bot
    func newTicketViewController(botLog: Data?) -> UIViewController?

    /// Creates a UIViewController that lets the user report an abusive profile
    ///
    /// - parameter reporter: The identity of the logged in user
    /// - parameter profile: The profile to report
    /// - parameter botLog: A Data object containing the log of the go bot
    func newTicketViewController(reporter: String, profile: AbusiveProfile, botLog: Data?) -> UIViewController?

    /// Creates a UIViewController that lets the user report an offensive content
    ///
    /// - parameter reporter: The identity of the logged in user
    /// - parameter content: The content to report
    /// - parameter botLog: A Data object containing the log of the go bot
    func newTicketViewController(reporter: String, content: OffensiveContent, botLog: Data?) -> UIViewController?
}
