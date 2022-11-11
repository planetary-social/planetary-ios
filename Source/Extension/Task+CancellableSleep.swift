//
//  Task+CancellableSleep.swift
//  Planetary
//
//  Created by Matthew Lorentz on 9/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Task where Success == Never, Failure == Never {
    
    /// Like `Task.sleep` but with cancellation support.
    /// from: https://forums.swift.org/t/running-an-async-task-with-a-timeout/49733/11
    ///
    /// - Parameter deadline: Sleep at least until this time. The actual time the sleep ends can be later.
    /// - Parameter cancellationCheckInterval: The interval in nanoseconds between cancellation checks.
    static func cancellableSleep(
        until deadline: Date,
        cancellationCheckInterval: UInt64 = 100_000
    ) async throws {
        while Date.now < deadline {
            guard !Task.isCancelled else {
                break
            }
            // Sleep for a while between cancellation checks.
            try await Task.sleep(nanoseconds: cancellationCheckInterval)
        }
    }
}
