//
//  IdentityManager.swift
//  FBTT
//
//  Created by Christoph on 2/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

// TODO https://app.asana.com/0/914798787098068/1108672560350393/f
// TODO use keychain instead
@available(*, deprecated)
class IdentityManager {

    static let shared = IdentityManager()
    private init() {}

    /// Returns array of all known identities from the storage.
    /// This is useful to show a list of identities to select from.
    /// This specifically does not return all Secrets because
    /// there is no need to deserialize all at the same time.
    func identities() -> [Identity] {
        UserDefaults.standard.identities
    }

    var selectedIdentity: Identity? {
        UserDefaults.standard.identity
    }

    func select(_ identity: Identity?) {

        if identity == nil {
            UserDefaults.standard.identity = nil
            return
        }
        
        let contains = self.identities().contains { $0 == identity }
        guard contains else { return }
        UserDefaults.standard.identity = identity
    }

    func secretForSelectedIdentity() -> Secret? {
        guard let identity = self.selectedIdentity else { return nil }
        return self.secret(for: identity)
    }

    /// Returns the secret for the specified Identity.
    /// Or nil if there is no matching secret.  Clients
    /// are recommended to not store the Secret themselves,
    /// but to instead manage the Identity and look up
    /// the Secret as needed.
    func secret(for identity: Identity) -> Secret? {
        let secrets = UserDefaults.standard.secrets
        let filtered = secrets.filter { $0.id == identity }
        return filtered.first
    }

    /// Serializes the specified Secret to secure storage.
    /// After this call completes, `identities()` will include
    /// this secret's identity.  If the specified Secret
    /// already has be added or there is an existing identity,
    /// the old Secret will be overwritten.  This prevents
    /// having multiple secrets with the same identity.
    func addOrReplace(_ secret: Secret) {

        // remove all for this identity
        self.removeSecret(for: secret.identity)

        // update identities
        let defaults = UserDefaults.standard
        var identities = defaults.identities
        identities += [secret.identity]
        defaults.identities = identities

        // update secrets
        var secrets = defaults.secrets
        secrets += [secret]
        defaults.secrets = secrets
    }

    /// Removes the specified Secret from storage.
    func removeSecret(for identity: Identity) {

        // update selected identity
        if self.selectedIdentity == identity {
            self.select(nil)
        }

        // update identities array
        let defaults = UserDefaults.standard
        var identities = defaults.identities
        identities.removeAll { $0 == identity }
        defaults.identities = identities

        // update secrets array
        var secrets = defaults.secrets
        secrets.removeAll { $0.identity == identity }
        defaults.secrets = secrets
    }

    func removeIdentitiesAndSecrets() {
        UserDefaults.standard.identity = nil
        UserDefaults.standard.identities = []
        UserDefaults.standard.secrets = []
    }
}

// TODO https://app.asana.com/0/914798787098068/1108672560350393/f
// TODO use keychain instead
fileprivate extension UserDefaults {

    var identity: Identity? {
        get {
            self.string(forKey: #function)
        }
        set {
            self.set(newValue, forKey: #function)
        }
    }

    var identities: [Identity] {
        get {
            let array = self.array(forKey: #function) as? [Identity]
            return array ?? []
        }
        set {
            self.set(newValue, forKey: #function)
        }
    }

    var secrets: [Secret] {
        get {
            let data = self.data(forKey: #function) ?? Data()
            let array = try? JSONDecoder().decode([Secret].self, from: data)
            return array ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            self.set(data, forKey: #function)
        }
    }
}
