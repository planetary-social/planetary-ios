//
//  UIViewController+TopViewController.swift
//  Planetary
//
//  Created by Christoph on 11/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {

    var isTopViewController: Bool {
        return self.navigationController?.topViewController == self
    }
}
