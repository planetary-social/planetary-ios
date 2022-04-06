//
//  RepeatingTimer.swift
//  FBTT
//
//  Created by Christoph on 5/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class RepeatingTimer {

    let interval: TimeInterval
    private var completion: (() -> Void)
    private var timer: Timer?

    var isRunning: Bool {
        self.timer != nil
    }

    init(interval: TimeInterval = 10, completion: @escaping (() -> Void)) {
        self.interval = interval
        self.completion = completion
    }

    func start(fireImmediately: Bool = false) {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            _ in
            self.completion()
        }
        if fireImmediately { self.completion() }
    }

    func stop() {
        self.timer?.invalidate()
        self.timer = nil
    }
}
