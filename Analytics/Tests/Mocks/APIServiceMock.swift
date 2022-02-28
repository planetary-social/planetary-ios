//
//  APIServiceMock.swift
//  
//
//  Created by Martin Dutra on 13/12/21.
//

import Foundation
@testable import Analytics

class APIServiceMock: APIService {

    var identified = false
    var forgot = false
    var tracked = false
    var lastTrackedEvent = ""

    var isEnabled: Bool {
        return true
    }

    func identify(identity: Identity) {
        identified = true
    }

    func identify(statistics: Statistics) {
        identified = true
    }

    func forget() {
        forgot = true
    }

    func track(event: String, params: [String: Any]?) {
        tracked = true
        lastTrackedEvent = event
    }

}
