//
//  AppConfiguration+Data.swift
//  FBTT
//
//  Created by Christoph on 5/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

extension AppConfiguration {

    func toData() -> Data? {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
        if data == nil { Log.unexpected(.missingValue, "Configuration could not be archived") }
        return data
    }

    static func from(_ data: Data) -> AppConfiguration? {
        guard let object = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) else { return nil }
        let configuration = object as? AppConfiguration
        if configuration == nil { Log.unexpected(.missingValue, "Configuration could not be unarchived") }
        return configuration
    }
}

extension AppConfigurations {

    func toData() -> Data? {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
        if data == nil { Log.unexpected(.missingValue, "[AppConfiguration] could not be archived") }
        return data
    }

    static func from(_ data: Data) -> [AppConfiguration] {
        guard let object = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) else { return [] }
        let configurations = object as? AppConfigurations
        if configurations == nil { Log.unexpected(.missingValue, "[AppConfiguration] could not be unarchived") }
        return configurations ?? []
    }
}
