//
//  ZendeskService.swift
//  
//
//  Created by Martin Dutra on 25/3/22.
//

import CommonUISDK
import Foundation
import Logger
import Secrets
import SupportSDK
import UIKit
import ZendeskCoreSDK

class ZendeskService: APIService {

    private let zendeskURL = "https://planetarysupport.zendesk.com"

    private let tintColor = UIColor(named: "defaultTint") ?? #colorLiteral(red: 0.3254901961, green: 0.2431372549, blue: 0.4862745098, alpha: 1)

    private let tags = [
        Bundle.main.versionAndBuild,
        UIDevice.current.model,
        UIDevice.current.systemName,
        UIDevice.current.systemVersion
    ]

    private let articleIDs = SupportArticleID()

    init(keys: Keys = Keys.shared) {
        Log.info("Configuring Zendesk...")
        guard let appID = keys.get(key: .zendeskAppID), let clientID = keys.get(key: .zendeskClientID) else {
            return
        }
        Zendesk.initialize(appId: appID, clientId: clientID, zendeskUrl: zendeskURL)
        SupportSDK.Support.initialize(withZendesk: Zendesk.instance)
        Zendesk.instance?.setIdentity(ZendeskCoreSDK.Identity.createAnonymous())
        CommonTheme.currentTheme.primaryColor = tintColor
    }

    func mainViewController() -> UIViewController? {
        ZDKHelpCenterUi.buildHelpCenterOverviewUi()
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

    func myTicketsViewController(reporter: Identifier, attachments: [Attachment]) -> UIViewController? {
        let config = RequestUiConfiguration()
        config.tags = tags + [reporter.key]
        config.fileAttachments = attachments.map { $0.requestAttachment }
        return RequestUi.buildRequestList(with: [config])
    }

    func newTicketViewController(
        reporter: Identifier,
        subject: SupportSubject,
        reason: SupportReason?,
        attachments: [Attachment]
    ) -> UIViewController? {
        let config = RequestUiConfiguration()
        config.fileAttachments = attachments.map { $0.requestAttachment }
        config.subject = subject.rawValue
        config.tags = self.tags + [reason?.rawValue].compactMap { $0 } + [reporter.key]
        return RequestUi.buildRequestUi(with: [config])
    }

    private func id(for article: SupportArticle) -> String {
        switch article {
        case .whatIsPlanetary:
            return articleIDs.whatIsPlanetary
        case .frequentlyAskedQuestions:
            return articleIDs.frequentlyAskedQuestions
        case .privacyPolicy:
            return articleIDs.privacyPolicy
        case .editPost:
            return articleIDs.editPost
        case .termsOfService:
            return articleIDs.termsOfService
        }
    }
}
