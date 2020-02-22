//
//  Support.swift
//  FBTT
//
//  Created by Christoph on 9/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import ZendeskCoreSDK
import ZendeskSDK

struct Support {

    static func configure() {
        Zendesk.initialize(appId: Environment.Zendesk.appId,
                           clientId: Environment.Zendesk.clientId,
                           zendeskUrl: Environment.Zendesk.url)
        SupportUI.initialize(withZendesk: Zendesk.instance)
        Zendesk.instance?.setIdentity(ZendeskCoreSDK.Identity.createAnonymous())
        Theme.currentTheme.primaryColor = UIColor.tint.default
    }
}

typealias RequestAttachments = [RequestAttachment]

extension RequestAttachments {

    mutating func add(_ attachment: RequestAttachment?) {
        guard let attachment = attachment else { return }
        self += [attachment]
    }
}
