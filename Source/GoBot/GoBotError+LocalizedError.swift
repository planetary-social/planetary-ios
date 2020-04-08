//
//  GoBotError+LocalizedError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/7/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension GoBotError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .alreadyStarted:
            return "Already logged in"
        case .duringProcessing(let string, let error):
            return "\(string): \(error.localizedDescription)"
        case .unexpectedFault:
            return "Unexpected fault"
        }
    }
    
}
