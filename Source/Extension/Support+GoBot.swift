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

    func newTicketViewController(reporter: String, profile: SupportProfile) -> UIViewController? {
        guard let logUrls = Bots.current.logFileUrls.first else {
            return newTicketViewController(reporter: reporter, profile: profile, botLog: nil)
        }
        do {
            let data = try Data(contentsOf: logUrls)
            return newTicketViewController(reporter: reporter, profile: profile, botLog: data)
        } catch {
            Log.optional(error)
            return newTicketViewController(reporter: reporter, profile: profile, botLog: nil)
        }
    }

    public func newTicketViewController(reporter: String, content: SupportContent) -> UIViewController? {
        guard let logUrls = Bots.current.logFileUrls.first else {
            return newTicketViewController(reporter: reporter, content: content, botLog: nil)
        }
        do {
            let data = try Data(contentsOf: logUrls)
            return newTicketViewController(reporter: reporter, content: content, botLog: data)
        } catch {
            Log.optional(error)
            return newTicketViewController(reporter: reporter, content: content, botLog: nil)
        }
    }
}
