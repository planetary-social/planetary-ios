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
        if url.scheme == URL.planetaryScheme,
            let tab = MainTab(urlPath: url.path) {
            let show = MainTab.createShowClosure(for: tab)
            show()
            return true
        }
        
        if url.scheme == URL.ssbScheme {
            let canRedeem = RoomInvitationRedeemer.canRedeem(url)
            if canRedeem {
                Task { await RoomInvitationRedeemer.redeem(url, in: AppController.shared, bot: Bots.current) }
                return true
            }
        }
        
        return false
    }
}
