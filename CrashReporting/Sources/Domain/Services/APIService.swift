//
//  APIService.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation

// This protocol specifies the functions that a Crash Reporting provider should implement
// If we plan to change from Bugsnag to another crash reporting service, it's just a matter of
// implementing APIService and switching to that class in Delivery/CrashReporting.swift

/// APIService provides functions to connect and send events to a Crash Reporting service
protocol APIService {

    /// Use this block to attach logs to all events sent to the Crash Reporting service
    var onEventHandler: (() -> Logs)? { get set }
    
    /// Identifies the current user
    func identify(identity: Identity)

    /// Removes information about the current user
    func forget()

    /// Leaves a breadcrumb
    ///
    /// A breadcrumb can be any event (user opened a screen, user sent the app to the background) that
    /// can be useful to debug crashes.
    func record(_ message: String)

    /// Sends an error to the Crash Reporting service
    func report(error: Error, metadata: [AnyHashable: Any]?)
}
