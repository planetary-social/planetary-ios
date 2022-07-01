//
//  NumberOfReportsOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 30/6/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Foundation
import Logger

class NumberOfReportsOperation: AsynchronousOperation {

    private(set) var numberOfReports = 0
    private var lastReport: Report

    init(lastReport: Report) {
        self.lastReport = lastReport
        super.init()
    }

    override func main() {
        Task {
            Log.info("NumberOfReportsOperation started.")
            do {
                numberOfReports = try await Bots.current.numberOfReports(since: lastReport)
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
            Log.info("NumberOfReportsOperation finished.")
            finish()
        }
    }
}
