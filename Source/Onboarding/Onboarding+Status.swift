//
//  Onboarding+Status.swift
//  Planetary
//
//  Created by Christoph on 11/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

extension Onboarding {

    enum Status: String, Codable {

        case notStarted
        case started
        case completed

        /// Convenience indicating if onboarding needs to be started or resumed.
        /// Will be false if the status is `.completed`.
        var isRequired: Bool {
            self != .completed
        }

        static let key = "onboarding.statuses"
    }

    /// Returns a dictionary of raw String Identity to String Onboarding.Status, inddicating
    /// the onboarding status for a particular identity.  The raw String values must be used
    /// to allow use of NSKeyedArchiver.
    private static func statuses() -> [String: String] {
        guard let data = Keychain.data(for: Status.key) else { return [:] }
        guard let object = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) else { return [:] }
        guard let dictionary = object as? [String: String] else { return [:] }
        return dictionary
    }

    /// Returns the current onboarding status for the specified identity.  If there is no
    /// known status, then `.notStarted` is returned.
    static func status(for identity: Identity) -> Status {
        let string = self.statuses()[identity] ?? ""
        return Status(rawValue: string) ?? .notStarted
    }

    /// Sets the status for an identity.  This will overwrite existing status, and should
    /// only have one status per identity.
    static func set(status: Status, for identity: Identity) {
        var dictionary = self.statuses()
        dictionary[identity] = status.rawValue
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: dictionary, requiringSecureCoding: false)
            Keychain.set(data, for: Status.key)
        } catch {
            Log.fatal(.missingValue, "Could not save onboarding.statuses to Keychain: \(error)")
        }
    }
}
