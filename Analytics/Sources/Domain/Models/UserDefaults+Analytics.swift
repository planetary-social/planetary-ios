//
//  UserDefaults+Analytics.swift
//  
//
//  Created by Martin Dutra on 12/1/22.
//

import Foundation

extension UserDefaults {

    func didTrack(_ event: String) {
        var events = Set(self.trackedEvents())
        events.update(with: event)
        self.setValue(Array(events), forKey: "trackedEvents")
    }

    func trackedEvents() -> Set<String> {
        let events = self.array(forKey: "trackedEvents") as? [String] ?? []
        return Set(events)
    }

    func clearTrackedEvents() {
        self.removeObject(forKey: "trackedEvents")
    }
    
}
