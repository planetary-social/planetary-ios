//
//  AsynchronousBlockOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 6/11/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class AsynchronousBlockOperation: AsynchronousOperation {
    
    var block: (AsynchronousBlockOperation) -> Void
    
    init(block: @escaping (AsynchronousBlockOperation) -> Void) {
        self.block = block
    }
    
    override func main() {
        self.block(self)
    }
}
