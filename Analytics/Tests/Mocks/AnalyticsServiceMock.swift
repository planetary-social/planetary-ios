//
//  AnalyticsServiceMock.swift
//  
//
//  Created by Martin Dutra on 30/11/21.
//

import Foundation
@testable import Analytics

class AnalyticsServiceMock: AnalyticsService {

    var identified = false
    var forgot = false
    var tracked = false
    var optedIn = true

    var isEnabled: Bool = true

    func identify(identity: Identity) {
        identified = true
    }

    func optIn() {
        optedIn = true
    }

    func optOut() {
        optedIn = false
    }

    func forget() {
        forgot = true
    }

    func track(event: Event, element: Element, name: String, params: [String: Any]?) {
        tracked = true
    }

}
