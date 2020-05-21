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
        return nil
    }
    
    func articleViewController(_ article: SupportArticle) -> UIViewController? {
        return nil
    }
    
    func myTicketsViewController(from reporter: Identity?) -> UIViewController? {
        return nil
    }
    
    func newTicketViewController() -> UIViewController? {
        return nil
    }
    
    func newTicketViewController(from reporter: Identity, reporting identity: Identity, name: String) -> UIViewController? {
        return nil
    }
    
    func newTicketViewController(from reporter: Identity, reporting content: KeyValue, reason: SupportReason, view: UIView?) -> UIViewController? {
        return nil
    }
    
    func id(for article: SupportArticle) -> String {
        return ""
    }
    
    func article(for id: String) -> SupportArticle? {
        return nil
    }
    
}
