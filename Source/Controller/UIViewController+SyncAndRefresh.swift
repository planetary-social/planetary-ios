//
//  UIViewController+SyncAndRefresh.swift
//  Planetary
//
//  Created by Christoph on 12/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {

    func registerDidSyncAndRefresh() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didSyncAndRefresh(notification:)),
                                               name: .didSyncAndRefresh,
                                               object: nil)
    }

    func deeregisterDidSyncAndRefresh() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .didSyncAndRefresh,
                                                  object: nil)
    }

    @objc
    func didSyncAndRefresh(notification: NSNotification) {
        // subclasses are encouraged to override
    }
}
