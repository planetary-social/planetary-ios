//
//  ZendeskSupport.swift
//  Planetary
//
//  Created by Martin Dutra on 4/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import ZendeskCoreSDK
import SupportSDK
import Logger
import Secrets

class ZendeskSupport: SupportService {
    
    private let zendeskURL = "https://planetarysupport.zendesk.com"
    private let tags = [Bundle.main.versionAndBuild, UIDevice.current.model, UIDevice.current.systemName, UIDevice.current.systemVersion]
    
    init() {
        Log.info("Configuring Zendesk...")
        let keys = Keys.shared
        guard let appID = keys.get(key: .zendeskAppID), let clientID = keys.get(key: .zendeskClientID) else {
            return
        }
        Zendesk.initialize(appId: appID,
                           clientId: clientID,
                           zendeskUrl: zendeskURL)
        SupportSDK.Support.initialize(withZendesk: Zendesk.instance)
        Zendesk.instance?.setIdentity(ZendeskCoreSDK.Identity.createAnonymous())
        Theme.currentTheme.primaryColor = UIColor.tint.default
    }
    
    func mainViewController() -> UIViewController? {
        ZDKHelpCenterUi.buildHelpCenterOverviewUi()
    }
    
    func articleViewController(_ article: SupportArticle) -> UIViewController? {
        let config = HelpCenterUiConfiguration()
        config.showContactOptions = false
        config.showContactOptionsOnEmptySearch = false
        return ZDKHelpCenterUi.buildHelpCenterArticleUi(withArticleId: id(for: article),
                                                        andConfigs: [config])
    }
    
    func myTicketsViewController(from reporter: Identity?) -> UIViewController? {
        let reporter = reporter ?? Identity.notLoggedIn
        let config = RequestUiConfiguration()
        config.tags = tags + [reporter]
        var attachments = [RequestAttachment]()
        if let log = Log.fileUrls.first, let data = try? Data(contentsOf: log) {
            attachments.append(RequestAttachment(filename: log.lastPathComponent, data: data, fileType: .plain))
        }
        if let log = Bots.current.logFileUrls.first, let data = try? Data(contentsOf: log) {
            attachments.append(RequestAttachment(filename: log.lastPathComponent, data: data, fileType: .plain))
        }
        config.fileAttachments = attachments
        return RequestUi.buildRequestList(with: [config])
    }
    
    func newTicketViewController() -> UIViewController? {
        _newTicketViewController()
    }
    
    func newTicketViewController(from reporter: Identity, reporting identity: Identity, name: String) -> UIViewController? {
        let attachment = RequestAttachment(filename: name,
                                           data: identity.utf8data(),
                                           fileType: .plain)
        return _newTicketViewController(from: reporter,
                                        subject: .userReport,
                                        attachments: [attachment],
                                        tags: [reporter])
    }
    
    func newTicketViewController(from reporter: Identity, reporting content: KeyValue, reason: SupportReason, view: UIView?) -> UIViewController? {
        // note that attachment order is important and it is
        // preferred that people see the screenshot first
        var attachments: [RequestAttachment] = []
        attachments.add(view?.requestAttachment())
        attachments += content.requestAttachments()
        return self._newTicketViewController(from: reporter,
                                             subject: .contentReport,
                                             attachments: attachments,
                                             tags: [reason.rawValue])
    }
    
    func id(for article: SupportArticle) -> String {
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
    
    func article(for id: String) -> SupportArticle? {
        switch id {
        case ids.whatIsPlanetary:
            return .whatIsPlanetary
        case ids.faq:
            return .faq
        case ids.privacyPolicy:
            return .privacyPolicy
        case ids.editPost:
            return .editPost
        case ids.termsOfService:
            return .termsOfService
        default:
            return nil
        }
    }
}

typealias RequestAttachments = [RequestAttachment]

extension RequestAttachments {

    mutating func add(_ attachment: RequestAttachment?) {
        guard let attachment = attachment else { return }
        self += [attachment]
    }
}

fileprivate extension String {

    /// Convenience to return UTF8 data for a string.  This it typically an optional value but
    /// since strings are internally represented as UTF8 or UTF16, a force unwrap is safe.
    /// https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
    func utf8data() -> Data {
        self.data(using: .utf8)!
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

fileprivate extension About {

    func requestAttachment() -> RequestAttachment {
        RequestAttachment(filename: self.nameOrIdentity,
                                 data: self.identity.utf8data(),
                                 fileType: .plain)
    }
}

fileprivate extension Identifier {

    func requestAttachment() -> RequestAttachment {
        RequestAttachment(filename: "content-identifier",
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

extension ZendeskSupport {
    
    enum SupportSubject: String {
        case bugReport = "Bug Report"
        case contentReport = "Content Report"
        case userReport = "User Report"
    }
    
    private func _newTicketViewController(from reporter: Identity? = nil,
                                          subject: SupportSubject = .bugReport,
                                          attachments: [RequestAttachment] = [],
                                          tags: [String] = []) -> UIViewController {
        var attachments = attachments
        if let log = Log.fileUrls.first, let data = try? Data(contentsOf: log) {
            attachments.append(RequestAttachment(filename: log.lastPathComponent, data: data, fileType: .plain))
        }
        if let log = Bots.current.logFileUrls.first, let data = try? Data(contentsOf: log) {
            attachments.append(RequestAttachment(filename: log.lastPathComponent, data: data, fileType: .plain))
        }
        let reporter = reporter ?? Identity.notLoggedIn
        let config = RequestUiConfiguration()
        config.fileAttachments = attachments
        config.subject = subject.rawValue
        config.tags = self.tags + tags + [reporter]
        return RequestUi.buildRequestUi(with: [config])
    }
}

private struct SupportArticleID {
    let faq = "360039199393"
    let privacyPolicy = "360036147293"
    let termsOfService = "360035642794"
    let whatIsPlanetary = "360036488373"
    let editPost = "360039199393"
}

private let ids = SupportArticleID()
