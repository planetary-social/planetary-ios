//
//  ZendeskSupport.swift
//  Planetary
//
//  Created by Martin Dutra on 4/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import ZendeskCoreSDK
import ZendeskSDK

typealias Support = ZendeskSupport

class ZendeskSupport: SupportService {
    
    static var shared: SupportService = ZendeskSupport()
    
    private var configured: Bool = false
    private let zendeskURL = "https://planetarysupport.zendesk.com"
    private let tags = [Bundle.current.versionAndBuild, UIDevice.current.model, UIDevice.current.systemName, UIDevice.current.systemVersion]
    
    func configure() {
        guard let appId = Environment.Zendesk.appId, let clientId = Environment.Zendesk.clientId else {
            configured = false
            return
        }
        Log.info("Configuring Zendesk...")
        Zendesk.initialize(appId: appId,
                           clientId: clientId,
                           zendeskUrl: zendeskURL)
        SupportUI.initialize(withZendesk: Zendesk.instance)
        Zendesk.instance?.setIdentity(ZendeskCoreSDK.Identity.createAnonymous())
        Theme.currentTheme.primaryColor = UIColor.tint.default
        configured = true
    }
    
    func mainViewController() -> UIViewController? {
        guard configured else {
            return nil
        }
        return ZDKHelpCenterUi.buildHelpCenterOverviewUi()
    }
    
    func articleViewController(_ article: SupportArticle) -> UIViewController? {
        guard configured else {
            return nil
        }
        let config = HelpCenterUiConfiguration()
        config.showContactOptions = false
        config.showContactOptionsOnEmptySearch = false
        return ZDKHelpCenterUi.buildHelpCenterArticleUi(withArticleId: article.rawValue,
                                                        andConfigs: [config])
    }
    
    func myTicketsViewController(from reporter: Identity?) -> UIViewController? {
        guard self.configured else {
            return nil
        }
        let reporter = reporter ?? Identity.notLoggedIn
        let config = RequestUiConfiguration()
        config.tags = tags + [reporter]
        return RequestUi.buildRequestList(with: [config])
    }
    
    func newTicketViewController() -> UIViewController? {
        return _newTicketViewController()
    }
    
    func newTicketViewController(from reporter: Identity, reporting identity: Identity, name: String) -> UIViewController? {
        guard self.configured else {
            return nil
        }
        let attachment = RequestAttachment(filename: name,
                                           data: identity.utf8data(),
                                           fileType: .plain)
        return _newTicketViewController(from: reporter,
                                        subject: .userReport,
                                        attachments: [attachment],
                                        tags: [reporter])
    }
    
    func newTicketViewController(from reporter: Identity, reporting content: KeyValue, reason: SupportReason, view: UIView?) -> UIViewController? {
        guard self.configured else {
            return nil
        }
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
        return self.data(using: .utf8)!
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

extension ZendeskSupport {
    
    enum SupportSubject: String {
        case bugReport = "Bug Report"
        case contentReport = "Content Report"
        case userReport = "User Report"
    }
    
    private func _newTicketViewController(from reporter: Identity? = nil,
                                          subject: SupportSubject = .bugReport,
                                          attachments: [RequestAttachment] = [],
                                          tags: [String] = []) -> UIViewController? {
        guard configured else {
            return nil
        }
        let reporter = reporter ?? Identity.notLoggedIn
        let config = RequestUiConfiguration()
        config.fileAttachments = attachments
        config.subject = subject.rawValue
        config.tags = self.tags + tags + [reporter]
        return RequestUi.buildRequestUi(with: [config])
    }
}

fileprivate struct SupportArticleID {
    let faq = ""
    let privacyPolicy = "360036147293"
    let termsOfService = "360035642794"
    let whatIsPlanetary = "360036488373"
    let editPost = "360035642794"
}

fileprivate let ids = SupportArticleID()

extension SupportArticle {
    
    init?(rawValue: String) {
        switch rawValue {
        case ids.whatIsPlanetary:
            self = .whatIsPlanetary
        case ids.faq:
            self = .faq
        case ids.privacyPolicy:
            self = .privacyPolicy
        case ids.editPost:
            self = .editPost
        case ids.termsOfService:
            self = .termsOfService
        default:
            return nil
        }
    }
    
    var rawValue: String {
        switch self {
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
    
}
