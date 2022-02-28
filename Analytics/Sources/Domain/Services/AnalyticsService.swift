//
//  AnalyticsService.swift
//  
//
//  Created by Martin Dutra on 30/11/21.
//

import Foundation

protocol AnalyticsService {

    var isEnabled: Bool { get }

    func identify(identity: Identity)
    func identify(statistics: Statistics)
    func forget()
    func track(event: Event, element: Element, name: String, params: [String: Any]?)

}

// MARK: Track single param
extension AnalyticsService {

    func track(event: Event, element: Element, name: String, param: String? = nil, value: String? = nil) {
        var params: [String: Any] = [:]
        if let param = param, let value = value {
            params[param] = value
        }
        self.track(event: event, element: element, name: name, params: params)
    }

}
