//
//  AppController+Progress.swift
//  FBTT
//
//  Created by Christoph on 5/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import SVProgressHUD
import UIKit

extension AppController {

    func showProgress(after: TimeInterval = 1) {
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.setBackgroundColor(UIColor.background.default)
        SVProgressHUD.setForegroundColor(UIColor.tint.default)
        SVProgressHUD.setGraceTimeInterval(after)
        SVProgressHUD.show()
    }

    func updateProgress(perc: Float64, status: String? = nil) {
        SVProgressHUD.showProgress(Float(perc/100), status: status)
    }
    
    func hideProgress(completion: (() -> Void)? = nil) {
        SVProgressHUD.dismiss() { completion?() }
    }
}
