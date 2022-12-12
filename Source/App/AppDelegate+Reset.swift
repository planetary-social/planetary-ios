//
//  AppDelegate+Reset.swift
//  Planetary
//
//  Created by Martin Dutra on 3/9/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AppDelegate {

    func resetIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "reset_on_start") else {
            return
        }
        
        Keychain.clear()
        
        let domain = Bundle.main.bundleIdentifier ?? ""
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }
}
