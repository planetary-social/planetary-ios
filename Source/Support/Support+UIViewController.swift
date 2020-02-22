//
//  SupportViewController.swift
//  FBTT
//
//  Created by Christoph on 9/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import ZendeskCoreSDK
import ZendeskSDK

extension Support {

    // MARK: Help content

    // values are taken from the Zendesk URLs
    enum Article: String {
        case faq
        case privacyPolicy = "360036147293"
        case termsOfService = "360035642794"
        case whatIsPlanetary = "360036488373"
    }

    // values are taken from the Zendesk URLs
    enum Category: Int {
        case policies = 0
        case releaseNotes = 10
    }

    static func mainViewController() -> UIViewController {
        return ZDKHelpCenterUi.buildHelpCenterOverviewUi()
    }

    static func categoryViewController(_ category: Category) -> UIViewController {
        let config = HelpCenterUiConfiguration()
        config.groupType = .category
        config.groupIds = [NSNumber(value: category.rawValue)]
        return ZDKHelpCenterUi.buildHelpCenterOverviewUi(withConfigs: [config])
    }

    // TODO https://app.asana.com/0/0/1140914217559977/f
    // TODO this is supposed to hide the top-right button but does not
    static func articleViewController(_ article: Article) -> UIViewController {
        let config = HelpCenterUiConfiguration()
        config.showContactOptions = false
        config.showContactOptionsOnEmptySearch = false
        return ZDKHelpCenterUi.buildHelpCenterArticleUi(withArticleId: article.rawValue,
                                                        andConfigs: [config])
    }

    // MARK: Support tickets

    enum Subject: String {
        case bugReport = "Bug Report"
        case contentReport = "Content Report"
        case userReport = "User Report"
    }

    enum Reason: String, CaseIterable {
        case abusive
        case copyright
        case offensive
        case other
    }

    // Tags that will be included with every ticket
    static let tags = [Bundle.current.versionAndBuild,
                       UIDevice.current.model,
                       UIDevice.current.systemName,
                       UIDevice.current.systemVersion]

    static func myTicketsViewController(from reporter: Identity? = nil) -> UIViewController {
        let reporter = reporter ?? Identity.notLoggedIn
        let config = RequestUiConfiguration()
        config.tags = Support.tags + [reporter]
        return RequestUi.buildRequestList(with: [config])
    }

    static func newTicketViewController(from reporter: Identity? = nil,
                                        subject: Subject = .bugReport,
                                        attachments: [RequestAttachment] = [],
                                        tags: [String] = []) -> UIViewController
    {
        let reporter = reporter ?? Identity.notLoggedIn
        let config = RequestUiConfiguration()
        config.fileAttachments = attachments
        config.subject = subject.rawValue
        config.tags = Support.tags + tags + [reporter]
        return RequestUi.buildRequestUi(with: [config])
    }

    static func newTicketViewController(from reporter: Identity,
                                        reporting identity: Identity,
                                        name: String) -> UIViewController
    {
        let attachment = RequestAttachment(filename: name,
                                           data: identity.utf8data(),
                                           fileType: .plain)
        return Support.newTicketViewController(from: reporter,
                                               subject: .userReport,
                                               attachments: [attachment],
                                               tags: [reporter])
    }

    static func newTicketViewController(from reporter: Identity,
                                        reporting content: KeyValue,
                                        reason: Reason,
                                        view: UIView? = nil) -> UIViewController
    {
        // note that attachment order is important and it is
        // preferred that people see the screenshot first
        var attachments: [RequestAttachment] = []
        attachments.add(view?.requestAttachment())
        attachments += content.requestAttachments()
        return Support.newTicketViewController(from: reporter,
                                               subject: .contentReport,
                                               attachments: attachments,
                                               tags: [reason.rawValue])
    }
}

fileprivate extension KeyValue {

    func requestAttachments() -> RequestAttachments {
        var attachments: RequestAttachments = []
        attachments.add(self.metadata.author.about?.requestAttachment())
        attachments.add(self.key.requestAttachment())
        return attachments
    }
}

fileprivate extension String {

    /// Convenience to return UTF8 data for a string.  This it typically an optional value but
    /// since strings are internally represented as UTF8 or UTF16, a force unwrap is safe.
    /// https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
    func utf8data() -> Data {
        return self.data(using: .utf8)!
    }
}

fileprivate extension About {

    func requestAttachment() -> RequestAttachment {
        return RequestAttachment(filename: self.nameOrIdentity,
                                 data: self.identity.utf8data(),
                                 fileType: .plain)
    }
}

fileprivate extension Identifier {

    func requestAttachment() -> RequestAttachment {
        return RequestAttachment(filename: "content-identifier",
                                 data: self.utf8data(),
                                 fileType: .plain)
    }
}

fileprivate extension UIView {

    func requestAttachment() -> RequestAttachment? {
        guard let data = self.jpegData() else { return nil }
        return RequestAttachment(filename: Date().shortDateTimeString,
                                 data: data,
                                 fileType: .jpg)
    }
}
