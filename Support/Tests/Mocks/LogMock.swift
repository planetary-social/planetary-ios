//
//  LogMock.swift
//  
//
//  Created by Martin Dutra on 26/4/22.
//

import Foundation
import Logger

class LogMock: LogProtocol {

    var fileUrls: [URL] {
        if let url = Bundle.module.url(forResource: "app_log", withExtension: "txt") {
            return [url]
        }
        return []
    }
    
    func optional(_ error: Error?, _ detail: String?) -> Bool {
        false
    }
    
    func info(_ string: String) {
        print(string)
    }
    
    func debug(_ string: String) {
        print(string)
    }

    func error(_ string: String) {
        print(string)
    }
    
    func unexpected(_ reason: Reason, _ detail: String?) {
        print(reason.rawValue)
    }
    
    func fatal(_ reason: Reason, _ detail: String?) {
        print(reason.rawValue)
    }
}
