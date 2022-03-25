//
//  SupportService.swift
//  Planetary
//
//  Created by Martin Dutra on 4/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

enum SupportArticle {
    
    case faq
    case privacyPolicy
    case termsOfService
    case whatIsPlanetary
    case editPost
}

enum SupportReason: String, CaseIterable {
    case abusive
    case copyright
    case offensive
    case other
}

/// A protocol that defines a stateless support API for use across
/// all layers of an application.  Clients are encouraged to
/// define `SupportService` to point to a specific implementation, like
/// `typealias SupportService = ZendeskCrashReporting`.
/// This allows the implementation to be changed on a per target level based on needs.

protocol SupportService {

    func mainViewController() -> UIViewController?
    
    func articleViewController(_ article: SupportArticle) -> UIViewController?
    
    func myTicketsViewController(from reporter: Identity?) -> UIViewController?
    
    func newTicketViewController() -> UIViewController?
    
    func newTicketViewController(from reporter: Identity, reporting identity: Identity, name: String) -> UIViewController?
    
    func newTicketViewController(from reporter: Identity, reporting content: KeyValue, reason: SupportReason, view: UIView?) -> UIViewController?
    
    func id(for article: SupportArticle) -> String
    
    func article(for id: String) -> SupportArticle?
}
