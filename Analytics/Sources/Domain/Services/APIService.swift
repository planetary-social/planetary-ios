//
//  APIService.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation

// This protocol specifies the functions that an Analytics provider should implement
// If we plan to change from Posthog to another analytics service, it's just a matter of
// implementing APIService and switching to that class in Delivery/Analytics.swift

/// APIService provides functions to connect and send events to an Analytics service
protocol APIService {

    /// If true the service is collecting events and sending them to the server
    var isEnabled: Bool { get }

    /// Store data to identify current user
    func identify(identity: Identity)

    /// Enable sending data to the server
    func optIn()

    /// Disable sending data to the server
    func optOut()

    /// Erase data that identifies the user (see identify)
    func forget()

    /// Add event to the event queue and send it to the server as needed
    func track(event: String, params: [String: Any]?)
}
