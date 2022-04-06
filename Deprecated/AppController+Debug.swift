//
//  AppController+Debug.swift
//  FBTT
//
//  Created by Christoph on 1/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension AppController {

    func showDebug() {
        let controller = UINavigationController(rootViewController: DebugViewController())
        self.present(controller, animated: true, completion: nil)
    }

#if DEBUG
    override var canBecomeFirstResponder: Bool {
        true
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        self.presentDebugViewController()
    }

    func presentDebugViewController() {
        guard self.presentingViewController == nil else { return }
        self.showDebug()
    }
#endif
}
