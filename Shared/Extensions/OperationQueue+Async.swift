//
//  OperationQueue+Async.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/17/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

extension OperationQueue {
    
    /// Allows you to await the completion of all operations currently in a serial queue. Behavior is undefined for
    /// concurrent queues.
    func drainQueue() async {
        await withUnsafeContinuation { continuation in
            addOperation {
                continuation.resume()
            }
        }
    }
}
