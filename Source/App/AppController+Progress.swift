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

    func showToast(_ text: String) {
        SVProgressHUD.setGraceTimeInterval(0)
        SVProgressHUD.setMinimumDismissTimeInterval(2)
        SVProgressHUD.showSuccess(withStatus: text)
    }
    
    func showProgress(after: TimeInterval = 0.3, statusText: String? = nil) {
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.setBackgroundColor(.appBackground)
        SVProgressHUD.setForegroundColor(UIColor.tint.default)
        SVProgressHUD.setGraceTimeInterval(after)
        SVProgressHUD.show(withStatus: statusText)
    }

    func updateProgress(perc: Float64, status: String? = nil) {
        SVProgressHUD.showProgress(Float(perc), status: status)
    }
    
    func hideProgress(completion: (() -> Void)? = nil) {
        SVProgressHUD.dismiss { completion?() }
    }
}
