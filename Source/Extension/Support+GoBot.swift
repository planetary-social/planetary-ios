//
//  Support+GoBot.swift
//  Planetary
//
//  Created by Martin Dutra on 28/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Support
import UIKit
import Logger

extension Support {
    func newTicketViewController() -> UIViewController? {
        guard let logUrls = Bots.current.logFileUrls.first else {
            return newTicketViewController(botLog: nil)
        }
        do {
            let data = try Data(contentsOf: logUrls)
            return newTicketViewController(botLog: data)
        } catch {
            Log.optional(error)
            return newTicketViewController(botLog: nil)
        }
    }

    func myTicketsViewController(from reporter: String?) -> UIViewController? {
        guard let logUrls = Bots.current.logFileUrls.first else {
            return myTicketsViewController(from: reporter, botLog: nil)
        }
        do {
            let data = try Data(contentsOf: logUrls)
            return myTicketsViewController(from: reporter, botLog: data)
        } catch {
            Log.optional(error)
            return myTicketsViewController(from: reporter, botLog: nil)
        }
    }

    func newTicketViewController(from reporter: String, reporting identity: String, name: String) -> UIViewController? {
        guard let logUrls = Bots.current.logFileUrls.first else {
            return newTicketViewController(from: reporter, reporting: identity, name: name, botLog: nil)
        }
        do {
            let data = try Data(contentsOf: logUrls)
            return newTicketViewController(from: reporter, reporting: identity, name: name, botLog: data)
        } catch {
            Log.optional(error)
            return newTicketViewController(from: reporter, reporting: identity, name: name, botLog: nil)
        }
    }

    public func newTicketViewController(
        from reporter: String,
        reporting contentRef: String,
        authorRef: String?,
        authorName: String?,
        reason: SupportReason,
        view: UIView?
    ) -> UIViewController? {
        guard let logUrls = Bots.current.logFileUrls.first else {
            return newTicketViewController(
                from: reporter,
                reporting: contentRef,
                authorRef: authorRef,
                authorName: authorName,
                reason: reason,
                view: view,
                botLog: nil
            )
        }
        do {
            let data = try Data(contentsOf: logUrls)
            return newTicketViewController(
                from: reporter,
                reporting: contentRef,
                authorRef: authorRef,
                authorName: authorName,
                reason: reason,
                view: view,
                botLog: data
            )
        } catch {
            Log.optional(error)
            return newTicketViewController(from: reporter, reporting: contentRef, authorRef: authorRef, authorName: authorName, reason: reason, view: view, botLog: nil)
        }
    }
}
