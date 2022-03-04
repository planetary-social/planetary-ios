//
//  Analytics+Debug.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import Foundation

public extension Analytics {

    func trackDidShareLogs() {
        service.track(event: .select, element: .action, name: "share_logs")
    }

    func trackDidLogout() {
        service.track(event: .select, element: .action, name: "logout")
    }

    func trackDidLogoutAndOnboard() {
        service.track(event: .select, element: .action, name: "logout_onboard")
    }

}
