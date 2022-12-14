//
//  AsynchronousOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 4/27/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

// https://stackoverflow.com/questions/43561169/trying-to-understand-asynchronous-operation-subclass
class AsynchronousOperation: Operation {
    @objc
    private enum State: Int {
        case ready
        case executing
        case finished
    }
    
    private var _state = State.ready
    private let stateQueue = DispatchQueue(
        label: Bundle.main.bundleIdentifier ?? "" + ".op.state",
        attributes: .concurrent
    )
    
    @objc private dynamic var state: State {
        get { stateQueue.sync { _state } }
        set { stateQueue.sync(flags: .barrier) { _state = newValue } }
    }
    
    override var isAsynchronous: Bool { true }
    override var isReady: Bool {
        super.isReady && state == .ready
    }
    
    override var isExecuting: Bool {
        state == .executing
    }
    
    override var isFinished: Bool {
        state == .finished
    }
    
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if ["isReady", "isFinished", "isExecuting"].contains(key) {
            return [#keyPath(state)]
        }
        return super.keyPathsForValuesAffectingValue(forKey: key)
    }
    
    override func start() {
        if isCancelled {
            finish()
            return
        }
        self.state = .executing
        main()
    }
    
    override func main() {
        Log.error("Called unimplementd function \(#function)")
    }
    
    final func finish() {
        if isExecuting {
            state = .finished
        }
    }
}
