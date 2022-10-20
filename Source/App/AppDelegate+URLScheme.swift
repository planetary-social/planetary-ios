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
        if url.scheme == URL.planetaryScheme {
            if let tab = MainTab(urlPath: url.path) {
                let show = MainTab.createShowClosure(for: tab)
                show()
                return true
            } else if let deepURL = URL(string: String(url.path.dropFirst())) {
                AppController.shared.open(url: deepURL)
                return true
            }
        }
        
        if url.scheme == URL.ssbScheme {
            let canRedeem = RoomInvitationRedeemer.canRedeem(redirectURL: url)
            if canRedeem {
                Task {
                    await RoomInvitationRedeemer.redeem(redirectURL: url, in: AppController.shared, bot: Bots.current)
                }
                return true
            }
            
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                components.path == "experimental",
                let queryParams = components.queryItems,
                let actionParam = queryParams.first(where: { $0.name == "action" }),
                actionParam.value == "consume-alias",
                let userIDParam = queryParams.first(where: { $0.name == "userId" })?.value {
                
                AppController.shared.pushViewController(for: .about, with: userIDParam)
            }
        }
        
        return false
    }
}
