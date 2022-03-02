//
//  AnalyticsServiceAdapter.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation
import Logger

class AnalyticsServiceAdapter: AnalyticsService {

    var isEnabled: Bool {
        return apiService.isEnabled
    }

    var apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func identify(identity: Identity) {
        Log.debug("Identified \(identity.identifier)")
        apiService.identify(identity: identity)
    }

    func optIn() {
        apiService.optIn()
    }

    func optOut() {
        apiService.optOut()
    }

    func forget() {
        apiService.forget()
    }

    func track(event: Event, element: Element, name: String, params: [String: Any]?) {
        let eventName = eventName(event: event, element: element, name: name)
        Log.debug("Tracked \(eventName)")
        apiService.track(event: eventName, params: params)
        UserDefaults.standard.didTrack(eventName)
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
