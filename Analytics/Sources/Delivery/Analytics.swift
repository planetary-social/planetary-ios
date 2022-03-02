//
//  Analytics.swift
//  
//
//  Created by Martin Dutra on 30/11/21.
//

import Foundation

public class Analytics {

    public static let shared = Analytics(service: AnalyticsServiceAdapter(apiService: PostHogService()))

    var service: AnalyticsService

    init(service: AnalyticsService) {
        self.service = service
    }

    public func identify(identifier: String, name: String?, network: String) {
        service.identify(identity: Identity(identifier: identifier, name: name, network: network))
    }

    public func forget() {
        service.forget()
    }

    public var isEnabled: Bool {
        return service.isEnabled
    }

    public func optIn() {
        service.optIn()
    }

    public func optOut() {
        service.optOut()
    }

    public func lexicon() -> [String] {
        // TODO: Implement
        return []
    }

    /// Clear tracked events in UserDefaults
    ///
    /// Mean to be used for debugging only. It doesn't clear events in the actual analytics service
    public func clearTrackedEvents() {
        UserDefaults.standard.clearTrackedEvents()
    }

    /// Return the list of events tracked so far
    ///
    /// Mean to be used for debugging only. It doesn't necessarily match the actual analytics service
    public func trackedEvents() -> Set<String> {
        return UserDefaults.standard.trackedEvents()
    }

}
