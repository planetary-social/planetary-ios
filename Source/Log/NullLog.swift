//
//  NullLog.swift
//  FBTT
//
//  Created by Christoph on 7/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias Log = NullLog

/// A null implementation of the LogService protocol suitable
/// for use with unit or API test targets.
class NullLog: LogService {

    static var fileUrls: [URL] = []
    
    static func configure() { }
    
    @discardableResult
    static func optional(_ error: Error?, _ detail: String? = nil) -> Bool {
        guard let error = error else {
            return false
        }
        print("ERROR: \(error.localizedDescription)")
        return true
    }

    static func info(_ string: String) {
        print("INFO: \(string)")
    }
    
    static func debug(_ string: String) {
        print("DEBUG: \(string)")
    }

    static func unexpected(_ reason: LogReason, _ detail: String? = nil) {
        switch reason {
        case .apiError:
            print("UNEXPECTED: API error (\(detail ?? "null"))")
        case .botError:
            print("UNEXPECTED: Bot error (\(detail ?? "null"))")
        case .incorrectValue:
            print("UNEXPECTED: Incorrect value (\(detail ?? "null"))")
        case .missingValue:
            print("UNEXPECTED: Missing value (\(detail ?? "null"))")
        }
    }

    static func fatal(_ reason: LogReason, _ detail: String? = nil) {
        switch reason {
        case .apiError:
            print("FATAL: API error (\(detail ?? "null"))")
        case .botError:
            print("FATAL: Bot error (\(detail ?? "null"))")
        case .incorrectValue:
            print("FATAL: Incorrect value (\(detail ?? "null"))")
        case .missingValue:
            print("FATAL: Missing value (\(detail ?? "null"))")
        }
    }
}
