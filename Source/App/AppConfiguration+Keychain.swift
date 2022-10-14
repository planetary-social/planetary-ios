//
//  AppConfiguration+Keychain.swift
//  FBTT
//
//  Created by Christoph on 5/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AppConfigurations {

    static var current: AppConfigurations {
        Keychain.configurations
    }

    static func add(_ configuration: AppConfiguration) {
        if let existingIndex = Keychain.configurations.firstIndex(where: {
            configuration.id == $0.id }) {
            Keychain.configurations[existingIndex] = configuration
        } else {
            Keychain.configurations += [configuration]
        }
    }

    static func delete(_ configuration: AppConfiguration) {
        configuration.unapplyIfCurrent()
        var configurations = Keychain.configurations
        guard let index = configurations.firstIndex(of: configuration) else { return }
        configurations.remove(at: index)
        Keychain.configurations = configurations
    }

    func save() {
        Keychain.configurations = self
    }

    func delete() {
        Keychain.configurations = []
    }
}

fileprivate extension Keychain {
    static var configurations: [AppConfiguration] {
        get {
            guard let data = Keychain.data(for: "app.configurations") else { return [] }
            let configurations = AppConfigurations.from(data)
            return configurations
        }
        set {
            if let data = newValue.toData() {
                Keychain.set(data, for: "app.configurations")
            } else {
                Keychain.delete("app.configurations")
            }
        }
    }
}
