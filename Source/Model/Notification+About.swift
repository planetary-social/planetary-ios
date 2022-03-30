//
//  Notification+About.swift
//  Planetary
//
//  Created by Martin Dutra on 3/24/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let didUpdateAbout = Notification.Name("didUpdateAbout")
}

extension Notification {

    var about: About? {
        self.userInfo?["about"] as? About
    }

    static func didUpdateAbout(_ about: About?) -> Notification {
        Notification(name: .didUpdateAbout,
                            object: nil,
                            userInfo: ["about": about])
    }
}
