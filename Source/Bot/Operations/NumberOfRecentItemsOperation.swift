//
//  NumberOfRecentItemsOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 22/6/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Foundation
import Logger

class NumberOfRecentItemsOperation: AsynchronousOperation {

    private(set) var numberOfRecentItems = 0
    private var lastMessage: MessageIdentifier

    init(lastMessage: MessageIdentifier) {
        self.lastMessage = lastMessage
        super.init()
    }

    override func main() {
        Task {
            Log.info("NumberOfRecentItemsOperation started.")
            do {
                numberOfRecentItems = try await Bots.current.numberOfRecentItems(since: lastMessage)
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
            Log.info("NumberOfRecentItemsOperation finished.")
            finish()
        }
    }
}
