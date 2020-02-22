//
//  UIViewController+ApplicationWillEnterForeground.swift
//  Planetary
//
//  Created by Christoph on 10/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {

    func registerApplicationWillEnterForeground() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    func deregisterApplicationWillEnterForeground() {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willEnterForegroundNotification,
                                                  object: nil)
    }

    @objc func applicationWillEnterForeground() {
        // subclasses are encouraged to override and implement
    }
}
