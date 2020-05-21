//
//  CrashReportingService.swift
//  Planetary
//
//  Created by Martin Dutra on 3/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A protocol that defines a stateless crash reporting API for use across
/// all layers of an application.

protocol CrashReportingService {
    
    func identify(about: About?, network: NetworkKey)
    func forget()
    
    func crash()
    
    func record(_ message: String)
    
    func reportIfNeeded(error: Error?)

    func reportIfNeeded(error: Error?, metadata: [AnyHashable: Any])
    
}
