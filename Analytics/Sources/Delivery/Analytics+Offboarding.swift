//
//  Analytics+Offboarding.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import Foundation

public extension Analytics {

    func trackOffboardingStart() {
        service.track(event: .did, element: .app, name: "offboarding_start")
    }

    func trackOffboardingEnd() {
        service.track(event: .did, element: .app, name: "offboarding_end")
    }

}
