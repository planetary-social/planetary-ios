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
    func mainViewController() -> UIViewController?

    func articleViewController(article: SupportArticle) -> UIViewController?

    func myTicketsViewController(reporter: Identifier, attachments: [Attachment]) -> UIViewController?

    func newTicketViewController(
        reporter: Identifier,
        subject: SupportSubject,
        reason: SupportReason?,
        attachments: [Attachment]
    ) -> UIViewController?
}
