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
}
