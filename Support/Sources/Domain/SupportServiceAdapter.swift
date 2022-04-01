//
//  SupportServiceAdapter.swift
//  
//
//  Created by Martin Dutra on 24/3/22.
//

import Foundation
import Logger
import UIKit

class SupportServiceAdapter: SupportService {

    var apiService: APIService

    init(_ apiService: APIService) {
        self.apiService = apiService
    }

    func mainViewController() -> UIViewController? {
        return apiService.mainViewController()
    }
    
    func articleViewController(for article: SupportArticle) -> UIViewController? {
        return apiService.articleViewController(article: article)
    }

    func myTicketsViewController(from identity: String?, botLog: Data?) -> UIViewController? {
        let reporter = Identifier(key: identity)
        var appLog: Data?
        if let log = Log.fileUrls.first {
            appLog = try? Data(contentsOf: log)
        }
        let logs = Logs(appLog: appLog, botLog: botLog)
        return apiService.myTicketsViewController(
            reporter: reporter,
            attachments: logs.attachments()
        )
    }

    func newTicketViewController(botLog: Data?) -> UIViewController? {
        var appLog: Data?
        if let log = Log.fileUrls.first {
            appLog = try? Data(contentsOf: log)
        }
        let logs = Logs(appLog: appLog, botLog: botLog)
        return apiService.newTicketViewController(
            reporter: Identifier(),
            subject: .bugReport,
            reason: nil,
            attachments: logs.attachments()
        )
    }

    func newTicketViewController(from identifier: Identifier, author: Author, botLog: Data?) -> UIViewController? {
        var appLog: Data?
        if let log = Log.fileUrls.first {
            appLog = try? Data(contentsOf: log)
        }
        let logs = Logs(appLog: appLog, botLog: botLog)
        return apiService.newTicketViewController(
            reporter: identifier,
            subject: .userReport,
            reason: nil,
            attachments: author.attachments() + logs.attachments()
        )
    }

    func newTicketViewController(from identifier: Identifier, content: Content, reason: SupportReason, botLog: Data?) -> UIViewController? {
        var appLog: Data?
        if let log = Log.fileUrls.first {
            appLog = try? Data(contentsOf: log)
        }
        let logs = Logs(appLog: appLog, botLog: botLog)
        return apiService.newTicketViewController(
            reporter: identifier,
            subject: .contentReport,
            reason: reason,
            attachments: content.attachments() + logs.attachments()
        )
    }

    
}
