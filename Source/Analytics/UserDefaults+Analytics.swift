//
//  UserDefaults+Analytics.swift
//  Planetary
//
//  Created by Christoph on 1/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
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
