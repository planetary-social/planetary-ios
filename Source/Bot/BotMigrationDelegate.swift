//
//  BotMigrationDelegate.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/18/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias MigrationOnRunningCallback = @convention(c) (Int64, Int64) -> Void
typealias MigrationOnErrorCallback = @convention(c) (Int64, Int64, Int64) -> Void
typealias MigrationOnDoneCallback = @convention(c) (Int64) -> Void

/// An object that receives callbacks from scuttlego while it is running migrations. These callbacks allow us to
/// show migration UI. See documentation for `ssbInit()` in `api-ios.go`.
protocol BotMigrationDelegate {
    var onRunningCallback: MigrationOnRunningCallback { get }
    var onErrorCallback: MigrationOnErrorCallback { get }
    var onDoneCallback: MigrationOnDoneCallback { get }
}

struct BotMigrationError: LocalizedError {
    var code: Int64
    
    var errorDescription: String? {
        "BotMigrationError code: \(code)"
    }
}

