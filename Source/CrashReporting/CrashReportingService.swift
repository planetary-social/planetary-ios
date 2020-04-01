//
//  CrashReportingService.swift
//  Planetary
//
//  Created by Martin Dutra on 3/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A protocol that defines a stateless crash reporting API for use across
/// all layers of an application.  Clients are encouraged to
/// define `CrashReporting` to point to a specific implementation, like
/// `typealias CrashReporting = BugsnagCrashReporting`.
/// This allows the implementation to be changed on a per target level based on needs.

protocol CrashReportingService {
    
    static var shared: CrashReportingService  { get }
    
    var about: About? { get set }
    
    func configure()
    
    func crash()
    
    func record(_ message: String)
    
    func reportIfNeeded(error: Error?)
    
}
