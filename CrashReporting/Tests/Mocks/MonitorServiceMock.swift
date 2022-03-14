//
//  MonitorServiceMock.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation
@testable import CrashReporting

class MonitorServiceMock: MonitorService {

    var identified: Bool = false
    var crashed: Bool = false
    var forgot: Bool = false
    var recorded: Bool = false

    func identify(identity: Identity) {
        identified = true
    }

    func forget() {
        forgot = true
    }

    func record(_ message: String) {
        recorded = true
    }

    func report(error: Error, metadata: [AnyHashable: Any]?) {
        crashed = true
    }

}
