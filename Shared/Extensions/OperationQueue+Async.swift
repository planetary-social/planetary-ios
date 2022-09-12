//
//  OperationQueue+Async.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/17/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

extension OperationQueue {

    /// Allows you to await the completion of all operations currently in a queue. This should be used instead of
    /// `addOperations(operations, waitUntilFinished: true)` which deadlocks all structured concurrency tasks.
    ///
    /// - Parameter pollTime: The time between checks for an empty queue, in nanoseconds.
    func drain(pollTime: UInt64 = 1_000_000) async throws {
        while operationCount > 0 {
            try await Task.sleep(nanoseconds: pollTime)
        }
    }
}
