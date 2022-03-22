//
//  CrashReporting+GoBot.swift
//  Planetary
//
//  Created by Martin Dutra on 21/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import CrashReporting
import Logger

extension CrashReporting {
    func reportIfNeeded(error: Error?, metadata: [AnyHashable: Any]? = nil) {
        guard let logUrls = Bots.current.logFileUrls.first else {
            reportIfNeeded(error: error, metadata: metadata, botLog: nil)
            return
        }
        do {
            let data = try Data(contentsOf: logUrls)
            let string = String(data: data, encoding: .utf8)
            reportIfNeeded(error: error, metadata: metadata, botLog: string)
        } catch {
            Log.optional(error)
            reportIfNeeded(error: error, metadata: metadata, botLog: nil)
        }
    }
}
