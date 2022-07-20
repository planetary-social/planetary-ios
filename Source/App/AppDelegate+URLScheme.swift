//
//  AppDelegate+URLScheme.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/20/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit

extension AppDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard url.scheme == URL.planetaryScheme else {
            return false
        }
        
        if let tab = MainTab(urlPath: url.path),
            let appController = window?.rootViewController {
            let show = MainTab.createShowClosure(for: tab)
            show()
        }
        
        return true
    }
}
