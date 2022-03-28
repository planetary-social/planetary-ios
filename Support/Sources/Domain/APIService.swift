//
//  APIService.swift
//  
//
//  Created by Martin Dutra on 25/3/22.
//

import Foundation
import UIKit

protocol APIService {

    /// ViewController to show when selecting show Support
    func mainViewController()  -> UIViewController?

    func articleViewController(article: SupportArticle) -> UIViewController?

    func myTicketsViewController(reporter: Identifier, logs: Logs) -> UIViewController?

    func newTicketViewController(logs: Logs) -> UIViewController?

    func newTicketViewController(reporter: Identifier, author: Author, logs: Logs) -> UIViewController?

    func newTicketViewController(reporter: Identifier, content: Content, reason: SupportReason, logs: Logs) -> UIViewController?

}
