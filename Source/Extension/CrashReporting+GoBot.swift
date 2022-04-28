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

    func registerBotLogHandler() {
        registerBotLogHandler {
            guard let url = Bots.current.logFileUrls.first else {
                return nil
            }
            do {
                let data = try Data(contentsOf: url)
                return String(data: data, encoding: .utf8)
            } catch {
                Log.optional(error)
            }
            return nil
        }
    }
}
