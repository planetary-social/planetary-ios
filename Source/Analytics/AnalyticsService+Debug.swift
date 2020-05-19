//
//  AnalyticsService+Debug.swift
//  Planetary
//
//  Created by Martin Dutra on 5/12/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AnalyticsService {
    
    func trackDidShareLogs() {
        self.track(event: .select, element: .action, name: "share_logs")
    }
    
    func trackDidLogout() {
        self.track(event: .select, element: .action, name: "logout")
    }
    
    func trackDidLogoutAndOnboard() {
        self.track(event: .select, element: .action, name: "logout_onboard")
    }
    
}
