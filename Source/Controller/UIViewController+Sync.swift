//
//  UIViewController+Sync.swift
//  Planetary
//
//  Created by Christoph on 12/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {

    func registerDidSync() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didSync(notification:)),
                                               name: .didSync,
                                               object: nil)
    }

    func deeregisterDidSync() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .didSync,
                                                  object: nil)
    }

    @objc
    func didSync(notification: NSNotification) {
        // subclasses are encouraged to override
    }
}
