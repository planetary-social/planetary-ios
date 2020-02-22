//
//  AppConfiguration+Migrate.swift
//  FBTT
//
//  Created by Christoph on 5/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AppConfiguration {

    // TODO https://app.asana.com/0/914798787098068/1125341035741855/f
    // remove before shipping
    static func migrateFromUserDefaultsToKeychain() {

        if let configuration = UserDefaults.standard.appConfiguration {
            configuration.apply()
            Log.info("Moved configuration '\(configuration.name)' to keychain")
        }

        let configurations = UserDefaults.standard.appConfigurations
        if configurations.isEmpty == false {
            configurations.save()
            Log.info("Moved \(configurations.count) configurations to keychain")
        }

        Log.info("Removing identity, identities, secrets, and configurations from UserDefaults")
        UserDefaults.standard.removeObject(forKey: "identity")
        UserDefaults.standard.removeObject(forKey: "identities")
        UserDefaults.standard.removeObject(forKey: "secrets")
        UserDefaults.standard.removeObject(forKey: "appConfiguration")
        UserDefaults.standard.removeObject(forKey: "appConfigurations")
        UserDefaults.standard.synchronize()
    }
}

// Old properties that are provided here to ease migration.
fileprivate extension UserDefaults {

    var appConfiguration: AppConfiguration? {
        guard let data = self.data(forKey: #function) else { return nil }
        guard let object = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) else { return nil }
        guard let configuration = object as? AppConfiguration else { return nil }
        configuration.secret = UserDefaults.standard.secrets.first
        return configuration
    }

    var appConfigurations: [AppConfiguration] {
        guard let data = self.data(forKey: #function) else { return [] }
        guard let object = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) else { return [] }
        guard let configurations = object as? [AppConfiguration] else { return [] }
        let secrets = UserDefaults.standard.secrets
        for (index, configuration) in configurations.enumerated() {
            configuration.secret = secrets[safe: index]
        }
        return configurations
    }

    var identities: [Identity] {
        get {
            let array = self.array(forKey: #function) as? [Identity]
            return array ?? []
        }
    }

    var secrets: [Secret] {
        get {
            let data = self.data(forKey: #function) ?? Data()
            let array = try? JSONDecoder().decode([Secret].self, from: data)
            return array ?? []
        }
    }
}
