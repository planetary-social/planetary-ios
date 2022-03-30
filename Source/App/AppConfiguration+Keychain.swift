//
//  AppConfiguration+Keychain.swift
//  FBTT
//
//  Created by Christoph on 5/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AppConfiguration {

    static var current: AppConfiguration? {
        Keychain.configuration
    }

    func apply() {
        Keychain.configuration = self
    }

    func unapply() {
        Keychain.configuration = nil
    }

    func unapplyIfCurrent() {
        if self.isCurrent { self.unapply() }
    }
}

extension AppConfigurations {

    static var current: AppConfigurations {
        Keychain.configurations
    }

    static func add(_ configuration: AppConfiguration) {
        if let _ = Keychain.configurations.firstIndex(of: configuration) { return }
        Keychain.configurations += [configuration]
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

    // TODO https://app.asana.com/0/914798787098068/1149043570373553/f
    // TODO if the keychain does not unlock fast enough then this will be nil
    static var configuration: AppConfiguration? {
        get {
            guard let data = Keychain.data(for: "app.configuration") else { return nil }
            return AppConfiguration.from(data)
        }
        set {
            if let data = newValue?.toData() {
                Keychain.set(data, for: "app.configuration")
            } else {
                Keychain.delete("app.configuration")
            }
        }
    }

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
