//
//  EveryoneViewController.swift
//  Planetary
//
//  Created by Rabble on 4/25/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

import UIKit

class EveryoneViewController: HomeViewController {
    
    
    
    override func load(animated: Bool = false) {
        Bots.current.refresh() { error, _ in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            Bots.current.everyone() { [weak self] roots, error in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                self?.refreshControl.endRefreshing()
                self?.removeLoadingAnimation()
                AppController.shared.hideProgress()
             
                if let error = error {
                    self?.alert(error: error)
                } else {
                    self?.update(with: roots, animated: animated)
                }
            }
        }
    }
    


}

