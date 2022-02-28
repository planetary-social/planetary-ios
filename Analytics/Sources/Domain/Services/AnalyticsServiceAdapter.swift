//
//  AnalyticsServiceAdapter.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation

class AnalyticsServiceAdapter: AnalyticsService {

    var isEnabled: Bool {
        return apiService.isEnabled
    }

    var apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func identify(identity: Identity) {
        apiService.identify(identity: identity)
    }

    func identify(statistics: Statistics) {
        apiService.identify(statistics: statistics)
    }

    func forget() {
        apiService.forget()
    }

    func track(event: Event, element: Element, name: String, params: [String: Any]?) {
        apiService.track(event: eventName(event: event, element: element, name: name), params: params)
    }

}

// MARK: Lexicon
extension AnalyticsService {

    /// Returns a underscored string that has merged the arguments.
    func eventName(event: Event, element: Element, name: String) -> String {
        let strings = [event.rawValue, element.rawValue, name]
        let merged = strings.joined(separator: "_")
        return merged
    }

}

