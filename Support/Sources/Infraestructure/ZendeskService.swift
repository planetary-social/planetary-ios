//
//  ZendeskService.swift
//  
//
//  Created by Martin Dutra on 25/3/22.
//

import Foundation
import Logger
import Secrets
import SupportSDK
import UIKit
import ZendeskCoreSDK

class ZendeskService: APIService {

    private let zendeskURL = "https://planetarysupport.zendesk.com"

    private let tintColor: UIColor = UIColor(named: "defaultTint") ?? #colorLiteral(red: 0.3254901961, green: 0.2431372549, blue: 0.4862745098, alpha: 1)
    
    private let tags = [
        Bundle.main.versionAndBuild,
        UIDevice.current.model,
        UIDevice.current.systemName,
        UIDevice.current.systemVersion
    ]

    init(keys: Keys = Keys.shared) {
        Log.info("Configuring Zendesk...")
        guard let appID = keys.get(key: .zendeskAppID), let clientID = keys.get(key: .zendeskClientID) else {
            return
        }
        Zendesk.initialize(appId: appID,
                           clientId: clientID,
                           zendeskUrl: zendeskURL)
        SupportSDK.Support.initialize(withZendesk: Zendesk.instance)
        Zendesk.instance?.setIdentity(ZendeskCoreSDK.Identity.createAnonymous())
        Theme.currentTheme.primaryColor = tintColor
    }

    func mainViewController() -> UIViewController? {
        return ZDKHelpCenterUi.buildHelpCenterOverviewUi()
    }

    func articleViewController(article: SupportArticle) -> UIViewController? {
        let config = HelpCenterUiConfiguration()
        config.showContactOptions = false
        config.showContactOptionsOnEmptySearch = false
        return ZDKHelpCenterUi.buildHelpCenterArticleUi(
            withArticleId: id(for: article),
            andConfigs: [config]
        )
    }

    func myTicketsViewController(reporter: Identifier, logs: Logs) -> UIViewController? {
        let config = RequestUiConfiguration()
        config.tags = tags + [reporter.key]
        config.fileAttachments = logs.requestAttachments()
        return RequestUi.buildRequestList(with: [config])
    }

    func newTicketViewController(logs: Logs) -> UIViewController? {
        return _newTicketViewController(
            reporter: Identifier(),
            subject: .bugReport,
            logs: logs
        )
    }
    
    func newTicketViewController(reporter: Identifier, author: Author, logs: Logs) -> UIViewController? {
        let attachment = author.requestAttachment()
        return _newTicketViewController(
            reporter: reporter,
            subject: SupportSubject.userReport,
            attachments: [attachment],
            tags: [],
            logs: logs
        )
    }

    func newTicketViewController(reporter: Identifier, content: Content, reason: SupportReason, logs: Logs) -> UIViewController? {
        let attachments = content.requestAttachments()
        return self._newTicketViewController(
            reporter: reporter,
            subject: SupportSubject.contentReport,
            attachments: attachments,
            tags: [reason.rawValue],
            logs: logs
        )
    }

    private struct SupportArticleID {
        let faq = "360039199393"
        let privacyPolicy = "360036147293"
        let termsOfService = "360035642794"
        let whatIsPlanetary = "360036488373"
        let editPost = "360039199393"
    }

    private let ids = SupportArticleID()

    private func id(for article: SupportArticle) -> String {
        switch article {
        case .whatIsPlanetary:
            return ids.whatIsPlanetary
        case .faq:
            return ids.faq
        case .privacyPolicy:
            return ids.privacyPolicy
        case .editPost:
            return ids.editPost
        case .termsOfService:
            return ids.termsOfService
        }
    }

    private func _newTicketViewController(reporter: Identifier,
                                          subject: SupportSubject,
                                          attachments: [RequestAttachment] = [],
                                          tags: [String] = [],
                                          logs: Logs) -> UIViewController {
        var attachments = attachments
        attachments.append(contentsOf: logs.requestAttachments())
        let config = RequestUiConfiguration()
        config.fileAttachments = attachments
        config.subject = subject.rawValue
        config.tags = self.tags + tags + [reporter.key]
        return RequestUi.buildRequestUi(with: [config])
    }
}
