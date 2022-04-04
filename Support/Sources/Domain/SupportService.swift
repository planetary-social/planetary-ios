//
//  SupportService.swift
//  
//
//  Created by Martin Dutra on 24/3/22.
//

import Foundation
import UIKit

protocol SupportService {

    func mainViewController() -> UIViewController?
    
    func articleViewController(for article: SupportArticle) -> UIViewController?

    func myTicketsViewController(from identity: String?, botLog: Data?) -> UIViewController?

    func newTicketViewController(botLog: Data?) -> UIViewController?

    func newTicketViewController(from identifier: Identifier, author: Author, botLog: Data?) -> UIViewController?

    func newTicketViewController(
        from identifier: Identifier,
        content: Content,
        reason: SupportReason,
        botLog: Data?
    ) -> UIViewController?
}
