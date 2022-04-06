//
//  NullSupport.swift
//  Planetary
//
//  Created by Martin Dutra on 4/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

/// A null implementation of the SupportService protocol suitable
/// for use with unit or API test targets.

class NullSupport: SupportService {
    
    func mainViewController() -> UIViewController? {
        nil
    }
    
    func articleViewController(_ article: SupportArticle) -> UIViewController? {
        nil
    }
    
    func myTicketsViewController(from reporter: Identity?) -> UIViewController? {
        nil
    }
    
    func newTicketViewController() -> UIViewController? {
        nil
    }
    
    func newTicketViewController(from reporter: Identity, reporting identity: Identity, name: String) -> UIViewController? {
        nil
    }
    
    func newTicketViewController(from reporter: Identity, reporting content: KeyValue, reason: SupportReason, view: UIView?) -> UIViewController? {
        nil
    }
    
    func id(for article: SupportArticle) -> String {
        ""
    }
    
    func article(for id: String) -> SupportArticle? {
        nil
    }
}
