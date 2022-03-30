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
        service.isEnabled
    }

    public func optIn() {
        service.optIn()
    }

    public func optOut() {
        service.optOut()
    }
}
